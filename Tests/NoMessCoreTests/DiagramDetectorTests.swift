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

@Suite struct RendersHTML {
    @Test func diagramInPreAndProseInParagraphs() {
        let html = RichText.html([
            .text("  First line\n  second line\n\n  New paragraph"),
            .diagram("│ a < b │"),
        ])
        #expect(html.contains("<p>First line<br>second line</p>"))
        #expect(html.contains("<p>New paragraph</p>"))
        #expect(html.contains("white-space: pre;\">│ a &lt; b │</pre>"))
        #expect(html.contains(#"<meta charset="utf-8">"#))
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
