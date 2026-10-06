/// A run of lines in copied text: ordinary prose, or a diagram/table whose
/// alignment depends on a monospaced font.
public enum Block: Equatable, Sendable {
    case text(String)
    /// Lines with their common indent removed.
    case diagram(String)
}

/// Finds box drawings, trees, braille charts and column-aligned tables so they
/// can be offered to rich-text destinations in a monospaced font.
public enum DiagramDetector {
    /// Splits `text` into prose and diagram blocks, or returns `nil` when it
    /// contains no diagram.
    public static func blocks(_ text: String) -> [Block]? {
        let lines = splitLines(text)
        let isDiagram = diagramMask(lines)
        guard isDiagram.contains(true) else { return nil }

        var blocks: [Block] = []
        var start = 0
        while start < lines.count {
            let kind = isDiagram[start]
            var end = start
            while end < lines.count, isDiagram[end] == kind { end += 1 }
            let chunk = Array(lines[start..<end])
            blocks.append(kind ? .diagram(dedent(chunk)) : .text(chunk.joined(separator: "\n")))
            start = end
        }
        return blocks
    }

    /// A terminal selection starts at the clicked column only on its first
    /// line; every later line starts at column 0. When a copy begins inside a
    /// diagram, the first line is therefore shifted left. Returns the text with
    /// the missing columns put back as spaces, or `nil` when the first line
    /// already lines up (or no shift clearly lines it up better).
    public static func restoringClippedFirstLine(_ text: String) -> String? {
        let lines = splitLines(text)
        let isDiagram = diagramMask(lines)
        guard lines.count >= 2, isDiagram[0], isDiagram[1] else { return nil }

        let rest = lines.dropFirst().prefix(while: { !isBlank($0) })
        let targets = rest.reduce(into: Set<Int>()) { $0.formUnion(anchorColumns($1)) }
        let firstAnchors = anchorColumns(lines[0])

        func score(_ shift: Int) -> Int {
            firstAnchors.filter { targets.contains($0 + shift) }.count
        }
        let unshifted = score(0)
        var best = (shift: 0, score: unshifted)
        for shift in 1...40 where score(shift) > best.score {
            best = (shift, score(shift))
        }
        // Several anchors must agree, and strictly better than leaving it.
        guard best.shift > 0, best.score >= 2, best.score > unshifted else { return nil }

        var output = lines
        output[0] = String(repeating: " ", count: best.shift) + output[0]
        return output.joined(separator: "\n")
    }

    private static func splitLines(_ text: String) -> [String] {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { String($0).trimmingTrailingSpaces() }
    }

    /// Which lines belong to a diagram.
    private static func diagramMask(_ lines: [String]) -> [Bool] {
        var isDiagram = lines.map(hasDiagramGlyphs)
        markAlignedTables(lines, &isDiagram)
        guard isDiagram.contains(true) else { return isDiagram }

        // Pull in neighbouring lines that belong to the drawing, such as a
        // lone "↓" or "v" between two boxes, but not sentences around it.
        var grew = true
        while grew {
            grew = false
            for i in lines.indices where !isDiagram[i] && !isBlank(lines[i]) && !isProse(lines[i]) {
                let besideDiagram = (i > 0 && isDiagram[i - 1]) || (i + 1 < lines.count && isDiagram[i + 1])
                if besideDiagram {
                    isDiagram[i] = true
                    grew = true
                }
            }
        }
        return isDiagram
    }

    /// Box drawing characters that only run sideways; they carry no
    /// information about which column a line is aligned to.
    private static let horizontalStrokes: Set<UInt32> = [
        0x2500, 0x2501, 0x2504, 0x2505, 0x2508, 0x2509, 0x254C, 0x254D, 0x2550,
        0x2574, 0x2576, 0x2578, 0x257A, 0x257C, 0x257E,
    ]

    /// Columns that should line up with the lines above and below: box corners,
    /// verticals and junctions, ASCII "|" and "+", and where text resumes
    /// after a gap of two or more spaces (table columns).
    private static func anchorColumns(_ line: String) -> Set<Int> {
        var result = columnStarts(line)
        var column = 0
        for c in line {
            if let v = c.unicodeScalars.first?.value {
                let isBoxJoint = (0x2500...0x257F).contains(v) && !horizontalStrokes.contains(v)
                if isBoxJoint || c == "|" || c == "+" { result.insert(column) }
            }
            column += DisplayWidth.of(c)
        }
        return result
    }

    /// Box drawing, block elements, braille (terminal charts), and ASCII
    /// tables such as "+----+" borders and "| a | b |" rows.
    static func hasDiagramGlyphs(_ line: String) -> Bool {
        if line.unicodeScalars.contains(where: { (0x2500...0x259F).contains($0.value) || (0x2800...0x28FF).contains($0.value) }) {
            return true
        }
        let trimmed = line.drop(while: { $0 == " " })
        if trimmed.hasPrefix("+"), trimmed.hasSuffix("+"), trimmed.contains("---") { return true }
        if trimmed.hasPrefix("|"), trimmed.hasSuffix("|"), trimmed.count > 1 { return true }
        return false
    }

    /// Marks runs of two or more lines whose columns line up: each line has
    /// gaps of two or more spaces, and neighbouring lines share a column where
    /// text resumes after such a gap.
    private static func markAlignedTables(_ lines: [String], _ isDiagram: inout [Bool]) {
        let columns = lines.map(columnStarts)
        var i = 0
        while i < lines.count {
            var j = i
            while j + 1 < lines.count, !columns[j].isEmpty, !columns[j + 1].isDisjoint(with: columns[j]) {
                j += 1
            }
            if j > i {
                for k in i...j { isDiagram[k] = true }
            }
            i = j + 1
        }
    }

    /// Display columns where text resumes after a run of two or more spaces,
    /// ignoring the line's indent.
    private static func columnStarts(_ line: String) -> Set<Int> {
        var result: Set<Int> = []
        var column = 0
        var spaces = 0
        var seenText = false
        for c in line {
            if c == " " {
                spaces += 1
            } else {
                if seenText, spaces >= 2 { result.insert(column) }
                seenText = true
                spaces = 0
            }
            column += DisplayWidth.of(c)
        }
        return result
    }

    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " }
    }

    /// A sentence: several single-spaced words, or a lead-in ending in ":".
    private static func isProse(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " })
        if trimmed.hasSuffix(":") { return true }
        let words = trimmed.split(separator: " ")
        return words.count >= 4 && !trimmed.contains("  ")
    }

    private static func dedent(_ lines: [String]) -> String {
        let indent = lines
            .filter { !isBlank($0) }
            .map { $0.prefix(while: { $0 == " " }).count }
            .min() ?? 0
        return lines.map { String($0.dropFirst(indent)) }.joined(separator: "\n")
    }
}

/// Renders blocks as HTML for the pasteboard: prose as paragraphs, diagrams
/// as `<pre>` so rich-text apps keep them monospaced.
public enum RichText {
    public static func html(_ blocks: [Block]) -> String {
        var body = ""
        for block in blocks {
            switch block {
            case .diagram(let diagram):
                body += #"<pre style="font-family: Menlo, Monaco, 'Courier New', monospace; white-space: pre;">"#
                body += escape(diagram) + "</pre>\n"
            case .text(let text):
                for paragraph in paragraphs(text) {
                    body += "<p>" + paragraph.map(escape).joined(separator: "<br>") + "</p>\n"
                }
            }
        }
        return #"<html><head><meta charset="utf-8"></head><body>"# + "\n" + body + "</body></html>"
    }

    /// Groups lines into paragraphs separated by blank lines, dropping indent.
    private static func paragraphs(_ text: String) -> [[Substring]] {
        var result: [[Substring]] = []
        var current: [Substring] = []
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.drop(while: { $0 == " " })
            if trimmed.isEmpty {
                if !current.isEmpty { result.append(current) }
                current = []
            } else {
                current.append(trimmed)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func escape<S: StringProtocol>(_ s: S) -> String {
        var out = ""
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(c)
            }
        }
        return out
    }
}

private extension String {
    func trimmingTrailingSpaces() -> String {
        var s = self[...]
        while let last = s.last, last == " " || last == "\t" { s = s.dropLast() }
        return String(s)
    }
}
