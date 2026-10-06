/// A table recovered from its text drawing.
public struct Table: Equatable, Sendable {
    public var header: [String]?
    public var rows: [[String]]
}

/// Turns drawn tables back into cells, so rich-text apps can show a real
/// table instead of a drawing whose columns depend on character widths.
enum TableParser {
    static func parse(_ diagram: String) -> Table? {
        let lines = diagram.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2, lines.allSatisfy({ !$0.isEmpty }) else { return nil }
        return parseBoxed(lines) ?? parseMarkdown(lines) ?? parseSpaceAligned(lines)
    }

    // MARK: Box drawing and ASCII tables

    /// ┌──┬──┐ / │a │b │ / ├──┼──┤ / └──┴──┘, or the same with + - |.
    private static func parseBoxed(_ lines: [String]) -> Table? {
        // The outer borders must be unbroken rules; boxes side by side in a
        // flow diagram have gaps between them.
        guard let top = lines.first, let bottom = lines.last,
              let first = top.first, let last = bottom.first,
              "┌╭+".contains(first), "└╰+".contains(last),
              top.allSatisfy({ "┌┐┬─━═╭╮+-=".contains($0) }),
              bottom.allSatisfy({ "└┘┴─━═╰╯+-=".contains($0) })
        else { return nil }

        var groups: [[[String]]] = [[]]
        var columns: Int?
        for line in lines.dropFirst().dropLast() {
            guard let start = line.first, let end = line.last else { return nil }
            if "├+".contains(start), "┤+".contains(end), isRule(line) {
                groups.append([])
            } else if "│|".contains(start), "│|".contains(end), line.count >= 2 {
                let cells = line.dropFirst().dropLast()
                    .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "│" || $0 == "|" })
                    .map { $0.trimmingSpaces() }
                guard columns == nil || columns == cells.count else { return nil }
                columns = cells.count
                groups[groups.count - 1].append(cells)
            } else {
                return nil
            }
        }
        groups.removeAll { $0.isEmpty }
        guard !groups.isEmpty, (columns ?? 0) >= 2 else { return nil }

        // With a rule under every row, a row's several lines are its cells
        // wrapped inside the box. With only the header rule, each line is a row.
        let header = groups.count > 1 ? merge(groups.removeFirst()) : nil
        let rows = groups.count > 1 ? groups.map(merge) : groups[0]
        return Table(header: header, rows: rows)
    }

    private static func isRule(_ line: String) -> Bool {
        line.allSatisfy { "─━═├┤┼┬┴╞╡╪+-=:".contains($0) }
    }

    /// Joins the wrapped lines of each cell.
    private static func merge(_ lines: [[String]]) -> [String] {
        guard let width = lines.first?.count else { return [] }
        return (0..<width).map { column in
            lines.map { $0[column] }.filter { !$0.isEmpty }.reduce("") { joined, piece in
                guard let a = joined.last, let b = piece.first else { return joined + piece }
                return joined + (DisplayWidth.isCJK(a) || DisplayWidth.isCJK(b) ? "" : " ") + piece
            }
        }
    }

    // MARK: Markdown tables

    /// | a | b | / |---|---| / | 1 | 2 |
    private static func parseMarkdown(_ lines: [String]) -> Table? {
        guard lines.count >= 3,
              lines.allSatisfy({ $0.hasPrefix("|") && $0.hasSuffix("|") }),
              lines[1].allSatisfy({ "|-: ".contains($0) })
        else { return nil }
        let cells = lines.map { line in
            line.dropFirst().dropLast().split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingSpaces() }
        }
        guard let columns = cells.first?.count, columns >= 2,
              cells.allSatisfy({ $0.count == columns })
        else { return nil }
        return Table(header: cells[0], rows: Array(cells.dropFirst(2)))
    }

    // MARK: Space-aligned columns

    /// NAME      STATUS    AGE / api       Running   3d — columns start where
    /// the header resumes after two or more spaces. Needs at least three
    /// columns, so a log line with one double space is not a table.
    private static func parseSpaceAligned(_ lines: [String]) -> Table? {
        guard lines.allSatisfy({ !$0.contains("│") && !$0.contains("|") }) else { return nil }
        let starts = columnStarts(lines[0])
        guard starts.count >= 2 else { return nil }

        var rows: [[String]] = []
        for line in lines {
            guard let cells = split(line, at: starts) else { return nil }
            rows.append(cells)
        }
        // kubectl / docker style headers are all capitals.
        let headerLooksLikeOne = rows[0].allSatisfy { cell in
            cell.contains(where: \.isLetter) && !cell.contains(where: \.isLowercase)
        }
        return headerLooksLikeOne
            ? Table(header: rows[0], rows: Array(rows.dropFirst()))
            : Table(header: nil, rows: rows)
    }

    private static func columnStarts(_ line: String) -> [Int] {
        var starts: [Int] = []
        var column = 0
        var spaces = 0
        for c in line {
            if c == " " {
                spaces += 1
            } else {
                if spaces >= 2, column > spaces { starts.append(column) }
                spaces = 0
            }
            column += DisplayWidth.of(c)
        }
        return starts
    }

    /// Splits at display columns; nil if text runs across a column start.
    private static func split(_ line: String, at starts: [Int]) -> [String]? {
        var cells: [String] = []
        var current = ""
        var column = 0
        var boundaries = starts[...]
        var previous: Character = " "
        for c in line {
            if let next = boundaries.first, column >= next {
                guard column == next, previous == " " else { return nil }
                cells.append(current.trimmingSpaces())
                current = ""
                boundaries = boundaries.dropFirst()
            }
            current.append(c)
            previous = c
            column += DisplayWidth.of(c)
        }
        cells.append(current.trimmingSpaces())
        // Short rows (empty trailing cells) are fine; pad them.
        while cells.count < starts.count + 1 { cells.append("") }
        return cells
    }
}

private extension StringProtocol {
    func trimmingSpaces() -> String {
        String(drop(while: { $0 == " " }).reversed().drop(while: { $0 == " " }).reversed())
    }
}
