import Testing
@testable import NoMessCore

@Suite struct DetectsDiagrams {
    @Test func boxDiagramWithArrowAndSurroundingProse() {
        let text = """
        ⏺ Here is how the clipboard flows through the app:

          ┌──────────┐     ┌──────────┐
          │ Terminal │ ──▶ │ NoMess   │
          └──────────┘     └──────────┘
                ↓
          ┌──────────┐
          │ Notes    │
          └──────────┘

          The plain text stays exactly the same as what you copied.
        """
        let blocks = DiagramDetector.blocks(text)
        #expect(blocks == [
            .text("⏺ Here is how the clipboard flows through the app:\n"),
            .diagram("""
            ┌──────────┐     ┌──────────┐
            │ Terminal │ ──▶ │ NoMess   │
            └──────────┘     └──────────┘
                  ↓
            ┌──────────┐
            │ Notes    │
            └──────────┘
            """),
            .text("\n  The plain text stays exactly the same as what you copied."),
        ])
    }

    @Test func tree() {
        let text = """
        Sources/
        ├── NoMess/
        │   └── PasteboardWatcher.swift
        └── NoMessCore/
        """
        #expect(DiagramDetector.blocks(text) == [.diagram(text)])
    }

    @Test func alignedTable() {
        let text = """
        NAME            STATUS      AGE
        nomess-api      Running     3d
        nomess-worker   Running     12d
        """
        #expect(DiagramDetector.blocks(text) == [.diagram(text)])
    }

    @Test func asciiTable() {
        let text = """
        +--------+-------+
        | name   | count |
        +--------+-------+
        | nomess | 3     |
        +--------+-------+
        """
        #expect(DiagramDetector.blocks(text) == [.diagram(text)])
    }

    @Test func markdownTable() {
        let text = "| App | Result |\n|-----|--------|\n| Notes | ok |"
        #expect(DiagramDetector.blocks(text) == [.diagram(text)])
    }

    @Test func brailleChart() {
        let text = "⡀⠄⠂⠁⠈⠐⠠⢀\n⣿⣿⣷⣶⣦⣤⣄⣀"
        #expect(DiagramDetector.blocks(text) == [.diagram(text)])
    }
}

@Suite struct IgnoresNonDiagrams {
    @Test func prose() {
        let text = """
        The watcher polls the pasteboard and only reads it for terminal copies.
        Everything else is left exactly as it was copied.
        """
        #expect(DiagramDetector.blocks(text) == nil)
    }

    @Test func singleLineWithDoubleSpace() {
        #expect(DiagramDetector.blocks("Done.  Moving on to the next step now.") == nil)
    }

    @Test func pipeInsideSentence() {
        #expect(DiagramDetector.blocks("Run ls | grep swift to list the files.") == nil)
    }
}

/// Widths like SF Mono's fallback: CJK 1.6 cells, CJK punctuation 0.8,
/// emoji 1.6 for a 1-column character, everything else exactly one cell.
private struct FakeMetrics: GlyphMetrics {
    func cells(_ c: Character) -> Double {
        if "、，".contains(c) { return 0.8 }
        if c == "▶️" { return 1.6 }
        return DisplayWidth.isCJK(c) ? 1.6 : 1
    }
}

@Suite struct RendersHTML {
    @Test func proseKeepsLinesBlankLinesAndNestedIndent() {
        let html = RichText.html([
            .text("  First line\n  second line\n\n  func poll() {\n      guard x  else { return }\n  }"),
        ], metrics: FakeMetrics())
        #expect(html.contains("<div>First line</div>\n<div>second line</div>\n<div><br></div>\n"))
        #expect(html.contains("<div>func poll() {</div>"))
        #expect(html.contains("<div>&nbsp;&nbsp;&nbsp;&nbsp;guard x &nbsp;else { return }</div>"))
        #expect(html.contains(#"<meta charset="utf-8">"#))
    }

    @Test func diagramInPreWithEscaping() {
        let html = RichText.html([.diagram("┌─┐\n│<│\n└─┘")], metrics: FakeMetrics())
        #expect(html.contains("white-space: pre;\">┌─┐\n│&lt;│\n└─┘</pre>"))
    }

    @Test func drawnTableBecomesRealTable() {
        let html = RichText.html([.diagram("""
        ┌──────┬─────┐
        │ 名稱 │ a<b │
        ├──────┼─────┤
        │ x    │ y   │
        └──────┴─────┘
        """)], metrics: FakeMetrics())
        #expect(!html.contains("<pre"))
        #expect(html.contains(">名稱</th><th"))
        #expect(html.contains(">a&lt;b</th>"))
        #expect(html.contains(">x</td><td"))
    }
}

@Suite struct ParsesTables {
    @Test func boxTableWithHeaderRuleOnly() {
        let table = TableParser.parse("""
        ┌──────────────────────┬──────────────────────┐
        │ 貼到哪裡             │ 拿到什麼             │
        ├──────────────────────┼──────────────────────┤
        │ 備忘錄、Notion、Mail │ HTML，表格用等寬字型 │
        │ 終端機、程式編輯器   │ 純文字，跟原本一樣   │
        └──────────────────────┴──────────────────────┘
        """)
        #expect(table == Table(header: ["貼到哪裡", "拿到什麼"], rows: [
            ["備忘錄、Notion、Mail", "HTML，表格用等寬字型"],
            ["終端機、程式編輯器", "純文字，跟原本一樣"],
        ]))
    }

    @Test func boxTableWithWrappedCells() {
        // A rule under every row: the lines between rules are one row.
        let table = TableParser.parse("""
        ┌────────┬──────────────┐
        │ App    │ Result       │
        ├────────┼──────────────┤
        │ Notes  │ real table   │
        │        │ with borders │
        ├────────┼──────────────┤
        │ 終端機 │ 純文字，     │
        │        │ 不變         │
        └────────┴──────────────┘
        """)
        #expect(table == Table(header: ["App", "Result"], rows: [
            ["Notes", "real table with borders"],
            ["終端機", "純文字，不變"],
        ]))
    }

    @Test func asciiTable() {
        let table = TableParser.parse("""
        +--------+-------+
        | name   | count |
        +--------+-------+
        | nomess | 3     |
        +--------+-------+
        """)
        #expect(table == Table(header: ["name", "count"], rows: [["nomess", "3"]]))
    }

    @Test func markdownTable() {
        let table = TableParser.parse("| App | Result |\n|-----|--------|\n| Notes | ok |")
        #expect(table == Table(header: ["App", "Result"], rows: [["Notes", "ok"]]))
    }

    @Test func spaceAlignedTable() {
        let table = TableParser.parse("""
        NAME            STATUS      RESTARTS   AGE
        nomess-api      Running     0          3d
        nomess-cron     Completed   0          5h
        """)
        #expect(table == Table(header: ["NAME", "STATUS", "RESTARTS", "AGE"], rows: [
            ["nomess-api", "Running", "0", "3d"],
            ["nomess-cron", "Completed", "0", "5h"],
        ]))
    }

    @Test func flowDiagramIsNotATable() {
        #expect(TableParser.parse("""
        ┌──────────┐     ┌──────────┐
        │ Terminal │ ──▶ │ NoMess   │
        └──────────┘     └──────────┘
        """) == nil)
    }

    @Test func logWithOneGapIsNotATable() {
        #expect(TableParser.parse("""
        2026-10-06 09:12:01 INFO  pasteboard changed
        2026-10-06 09:12:07 INFO  joined 4 wrapped lines
        """) == nil)
    }

    @Test func treeIsNotATable() {
        #expect(TableParser.parse("nomess/\n├── Sources/\n└── Tests/") == nil)
    }
}

@Suite struct PadsToTerminalColumns {
    @Test func cjkRowGetsSpacesBeforeVerticals() {
        // 4 CJK × 0.4 short = 1.6 → 2 spaces before the first "│" (0.4 over);
        // then 4 × 0.4 − 0.4 = 1.2 → 1 space before the second.
        #expect(RichText.padToTerminalColumns("│ 貼到哪裡 │ 拿到什麼 │", metrics: FakeMetrics())
            == "│ 貼到哪裡   │ 拿到什麼  │")
    }

    @Test func narrowPunctuationCountsFully() {
        // 備忘錄 3 × 0.4 + 、 1.2 = 2.4 → 2 spaces.
        #expect(RichText.padToTerminalColumns("│ 備忘錄、 │", metrics: FakeMetrics()) == "│ 備忘錄、   │")
    }

    @Test func spaceAlignedColumnsGetSpacesBeforeNextColumn() {
        // 5 × 0.4 = 2 → 2 spaces.
        #expect(RichText.padToTerminalColumns("終端機程式  Running", metrics: FakeMetrics())
            == "終端機程式    Running")
    }

    @Test func wideEmojiTakesSpacesAway() {
        // ▶️ drawn 0.6 wider than its column: one space fewer before "│".
        #expect(RichText.padToTerminalColumns("│ ▶️  │", metrics: FakeMetrics()) == "│ ▶️ │")
    }

    @Test func linesWithoutWideGlyphsAreUnchanged() {
        let line = "┌──────────┐     ┌──────────┐"
        #expect(RichText.padToTerminalColumns(line, metrics: FakeMetrics()) == line)
    }

    @Test func realMenloMetricsMeasureCJKNarrowerThanTwoCells() {
        let menlo = CoreTextMetrics.menlo()
        #expect(menlo.cells("A") == 1)
        #expect(menlo.cells("貼") > 1.5 && menlo.cells("貼") < 1.9)
    }
}

@Suite struct RendersMarkdown {
    @Test func fencedDiagramsArePadded() {
        #expect(RichText.markdown([.diagram("│ 貼到哪裡 │")], metrics: FakeMetrics()) == "```\n│ 貼到哪裡   │\n```")
    }

    @Test func fencesDiagramsOnly() {
        let markdown = RichText.markdown([
            .text("Here is the flow:\n"),
            .diagram("┌───┐\n│ a │\n└───┘"),
            .text("\nDone."),
        ], metrics: FakeMetrics())
        #expect(markdown == "Here is the flow:\n\n```\n┌───┐\n│ a │\n└───┘\n```\n\nDone.")
    }
}

@Suite struct RestoresClippedFirstLine {
    private let box = """
      ┌──────────┐     ┌──────────┐
      │ Terminal │ ──▶ │ NoMess   │
      └──────────┘     └──────────┘
    """

    @Test func wholeIndentMissing() {
        let clipped = String(box.dropFirst(2))
        #expect(DiagramDetector.restoringClippedFirstLine(clipped) == box)
    }

    @Test func oneColumnMissing() {
        let clipped = String(box.dropFirst(1))
        #expect(DiagramDetector.restoringClippedFirstLine(clipped) == box)
    }

    @Test func cornerItselfMissing() {
        // Selection began one column into the box: the corner is gone, but the
        // rest of the line still has to sit over the verticals.
        let clipped = String(box.dropFirst(3))
        #expect(DiagramDetector.restoringClippedFirstLine(clipped) == "   " + clipped)
    }

    @Test func tableHeader() {
        let table = """
          NAME            STATUS      AGE
          nomess-api      Running     3d
          nomess-worker   Running     12d
        """
        #expect(DiagramDetector.restoringClippedFirstLine(String(table.dropFirst(2))) == table)
    }

    @Test func alignedBoxIsLeftAlone() {
        #expect(DiagramDetector.restoringClippedFirstLine(box) == nil)
    }

    @Test func narrowerFirstBoxIsLeftAlone() {
        let text = """
        ┌───┐
        │ a ├──────┐
        └───┘      │
        """
        #expect(DiagramDetector.restoringClippedFirstLine(text) == nil)
    }

    @Test func treeRootIsLeftAlone() {
        let text = """
        Sources/
        ├── NoMess/
        └── NoMessCore/
        """
        #expect(DiagramDetector.restoringClippedFirstLine(text) == nil)
    }

    @Test func proseFirstLineIsLeftAlone() {
        let text = """
        Here is the layout:
          ┌──────┐
          │ box  │
          └──────┘
        """
        #expect(DiagramDetector.restoringClippedFirstLine(text) == nil)
    }
}
