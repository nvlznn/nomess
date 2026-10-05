/// Rejoins lines that a terminal (or a TUI such as Claude Code) broke only
/// because the window was too narrow.
///
/// The rules are deliberately conservative: a wrong join is worse than a
/// missed one, so every check below has to pass before two lines are joined.
public enum HardWrapCleaner {
    /// Text whose widest line is narrower than this is never touched; real
    /// terminals are wider, and short snippets are rarely wrapped prose.
    public static let minimumWidth = 40

    /// Returns the cleaned text, or `nil` when nothing looked like a hard wrap
    /// (callers should then leave the clipboard alone).
    public static func clean(_ text: String) -> String? {
        // "\r\n" is a single Character, so isNewline handles CRLF too.
        let lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { Line(String($0).trimmingTrailingWhitespace()) }
        guard lines.count >= 2 else { return nil }

        let width = lines.map { $0.width }.max() ?? 0
        guard width >= minimumWidth else { return nil }

        // Without a TUI marker to go on, a single long line followed by a
        // short one is not proof of wrapping. Ask for at least two lines that
        // reach close to the right edge before trusting the edge.
        let nearEdge = lines.filter { !$0.isBlank && $0.width >= width - wrapSlack }.count
        let hasWrapEdge = nearEdge >= 2

        var output: [String] = []
        var paragraph: Paragraph?
        var inFence = false
        var didJoin = false

        func flush() {
            if let p = paragraph { output.append(p.text) }
            paragraph = nil
        }

        for (index, line) in lines.enumerated() {
            if line.isFence || inFence {
                if line.isFence { inFence.toggle() }
                flush()
                output.append(line.raw)
                continue
            }

            if let p = paragraph,
               let separator = joinSeparator(p, line, width: width, hasWrapEdge: hasWrapEdge) {
                paragraph?.append(line, separator: separator)
                didJoin = true
            } else {
                flush()
                // A selection usually starts mid-line, so the first line of
                // the copy may have lost its indent (and any "⏺ " marker).
                paragraph = Paragraph(line, mayBeClipped: index == 0)
            }
        }
        flush()

        return didJoin ? output.joined(separator: "\n") : nil
    }

    /// How far short of the right edge a word-wrapped line can end.
    static let wrapSlack = 15

    /// The string to put between the paragraph and `next` if `next` is a
    /// wrapped continuation, or `nil` if the line break is real.
    private static func joinSeparator(_ p: Paragraph, _ next: Line, width: Int, hasWrapEdge: Bool) -> String? {
        let prev = p.last
        guard !prev.isBlank, !next.isBlank else { return nil }

        // Continuation lines line up with the paragraph's text column
        // (e.g. two spaces under "⏺ "), or with the paragraph's own indent,
        // and once chosen every later continuation uses the same indent.
        let alignedUnderMarker = p.first.markerPrefixLength == next.indent
        let clippedStart = p.continuationIndent == nil && p.mayBeClipped
            && p.first.indent == 0 && p.first.markerPrefixLength == nil && next.indent > 0
        if let continuationIndent = p.continuationIndent {
            guard next.indent == continuationIndent else { return nil }
        } else {
            guard alignedUnderMarker || next.indent == p.first.indent || clippedStart else { return nil }
        }
        // The columns the selection cut off still counted toward the wrap.
        let prevWidth = prev.width + (clippedStart ? next.indent : 0)

        guard !next.startsWithStructure,
              !prev.looksLikeCodeOrTable, !next.looksLikeCodeOrTable,
              !prev.endsWithBreakingPunctuation
        else { return nil }

        guard let nextFirst = next.content.first, let prevLast = prev.raw.last else { return nil }
        let cjkBoundary = DisplayWidth.isCJK(prevLast) || DisplayWidth.isCJK(nextFirst)

        // Word wrap only breaks between words; a single token (file name,
        // hash, URL) on its own line is a list item, not a wrapped sentence.
        guard cjkBoundary || prev.text.contains(" ") else { return nil }

        if !alignedUnderMarker {
            guard hasWrapEdge else { return nil }
            // "end of sentence.\nNew sentence" in unmarked text is more likely
            // a deliberate line per record than a wrap.
            if ".!?".contains(prevLast), nextFirst.isUppercase { return nil }
        }

        // The break is a wrap only if the next word would not have fit on the
        // previous line. Between two CJK characters there was no space; next
        // to Latin text there may have been one, which the wrap swallowed.
        let fitsWithoutSpace = prevWidth + next.firstWordWidth <= width
        let fitsWithSpace = prevWidth + 1 + next.firstWordWidth <= width
        let bothCJK = DisplayWidth.isCJK(prevLast) && DisplayWidth.isCJK(nextFirst)
        if bothCJK { return fitsWithoutSpace ? nil : "" }
        if cjkBoundary {
            if !fitsWithoutSpace { return "" }
            return fitsWithSpace ? nil : " "
        }
        return fitsWithSpace ? nil : " "
    }
}

private struct Paragraph {
    let first: Line
    /// The first line may be missing its start because the selection began mid-line.
    let mayBeClipped: Bool
    private(set) var last: Line
    private(set) var text: String
    /// Indent shared by the continuation lines, fixed by the first join.
    private(set) var continuationIndent: Int?

    init(_ line: Line, mayBeClipped: Bool) {
        first = line
        self.mayBeClipped = mayBeClipped
        last = line
        text = line.raw
    }

    mutating func append(_ line: Line, separator: String) {
        text += separator + line.content
        last = line
        if continuationIndent == nil { continuationIndent = line.indent }
    }
}

private struct Line {
    let raw: String
    let width: Int
    /// Number of leading spaces.
    let indent: Int
    /// `raw` without its leading spaces.
    let content: Substring
    /// `raw` after its list/TUI marker (or `content` when there is none).
    let text: Substring
    /// Columns taken by indent + marker + following spaces, if a marker is present.
    let markerPrefixLength: Int?

    init(_ raw: String) {
        self.raw = raw
        width = DisplayWidth.of(raw)
        content = raw.drop(while: { $0 == " " })
        indent = raw.count - content.count
        if let marker = Line.markerLength(content) {
            let afterMarker = content.dropFirst(marker)
            let rest = afterMarker.drop(while: { $0 == " " })
            markerPrefixLength = indent + marker + (afterMarker.count - rest.count)
            text = rest
        } else {
            markerPrefixLength = nil
            text = content
        }
    }

    var isBlank: Bool { content.isEmpty }

    var isFence: Bool { content.hasPrefix("```") || content.hasPrefix("~~~") }

    var firstWordWidth: Int {
        guard let first = content.first else { return 0 }
        if DisplayWidth.isCJK(first) { return DisplayWidth.of(first) }
        return DisplayWidth.of(content.prefix(while: { $0 != " " }))
    }

    /// Lines that start something new and must never be glued to the line above.
    var startsWithStructure: Bool {
        guard let first = content.first else { return false }
        if Line.markerLength(content) != nil { return true }
        if first.isNumber { return true } // timestamps, numbered output, versions
        if "#>|-*+❯".contains(first) { return true }
        if content.hasPrefix("$ ") || content.hasPrefix("% ") { return true }
        return false
    }

    /// Column-aligned output, tables, tabs and box drawing.
    var looksLikeCodeOrTable: Bool {
        if raw.contains("\t") { return true }
        if text.contains("  ") { return true }
        if raw.unicodeScalars.contains(where: { (0x2500...0x257F).contains($0.value) }) { return true }
        return false
    }

    /// Endings that usually mean the author broke the line on purpose.
    var endsWithBreakingPunctuation: Bool {
        guard let last = raw.last else { return false }
        return "{};\\:".contains(last)
    }

    /// Length of a bullet / numbered-list / TUI marker at the start of
    /// `content`, not counting the space after it. Requires a following space.
    static func markerLength(_ content: Substring) -> Int? {
        let bullets: Set<Character> = ["-", "*", "+", "•", "◦", "●", "⏺", "⎿"]
        if let first = content.first, bullets.contains(first), content.dropFirst().first == " " {
            return 1
        }
        let digits = content.prefix(while: { $0.isASCII && $0.isNumber })
        if (1...3).contains(digits.count) {
            let rest = content.dropFirst(digits.count)
            if let mark = rest.first, mark == "." || mark == ")", rest.dropFirst().first == " " {
                return digits.count + 1
            }
        }
        return nil
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = self[...]
        while let last = s.last, last == " " || last == "\t" { s = s.dropLast() }
        return String(s)
    }
}
