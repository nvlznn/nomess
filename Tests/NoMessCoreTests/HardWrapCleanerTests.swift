import Foundation
import Testing
@testable import NoMessCore

/// Word-wraps `text` the way a terminal TUI does: `first` prefixes the first
/// line, `rest` prefixes continuation lines, no line exceeds `width` columns.
private func wrap(_ text: String, width: Int, first: String = "", rest: String = "") -> String {
    var lines: [String] = []
    var current = first
    var currentIsEmpty = true
    for word in text.split(separator: " ") {
        let candidate = currentIsEmpty ? current + word : current + " " + word
        if DisplayWidth.of(candidate) > width, !currentIsEmpty {
            lines.append(current)
            current = rest + word
        } else {
            current = candidate
        }
        currentIsEmpty = false
    }
    lines.append(current)
    return lines.joined(separator: "\n")
}

/// Character-wraps CJK text at `width` columns.
private func wrapCJK(_ text: String, width: Int, first: String = "", rest: String = "") -> String {
    var lines: [String] = []
    var current = first
    for c in text {
        if DisplayWidth.of(current + String(c)) > width {
            lines.append(current)
            current = rest
        }
        current.append(c)
    }
    lines.append(current)
    return lines.joined(separator: "\n")
}

private let prose = "The pasteboard watcher only reads contents when the frontmost app is a terminal, which keeps the privacy surface small and avoids touching anything copied from a browser or an editor."

@Suite struct Rejoins {
    @Test func claudeCodeBullet() {
        let wrapped = wrap(prose, width: 60, first: "⏺ ", rest: "  ")
        #expect(wrapped.contains("\n"))
        #expect(HardWrapCleaner.clean(wrapped) == "⏺ " + prose)
    }

    @Test func claudeCodeToolResult() {
        let wrapped = wrap(prose, width: 70, first: "  ⎿  ", rest: "     ")
        #expect(HardWrapCleaner.clean(wrapped) == "  ⎿  " + prose)
    }

    @Test func plainParagraph() {
        let wrapped = wrap(prose, width: 50)
        #expect(HardWrapCleaner.clean(wrapped) == prose)
    }

    @Test func indentedParagraphsKeepBlankLines() {
        let a = wrap(prose, width: 60, first: "  ", rest: "  ")
        let b = wrap(prose, width: 60, first: "  ", rest: "  ")
        #expect(HardWrapCleaner.clean(a + "\n\n" + b) == "  " + prose + "\n\n  " + prose)
    }

    @Test func listItemsStaySeparate() {
        let item = "Detect whether the copy came from a terminal before reading anything at all from the pasteboard"
        let text = wrap(item, width: 50, first: "- ", rest: "  ") + "\n" + wrap(item, width: 50, first: "- ", rest: "  ")
        #expect(HardWrapCleaner.clean(text) == "- " + item + "\n- " + item)
    }

    @Test func numberedList() {
        let item = "Write the cleaned text back so the next paste already gets the clean version of it"
        let text = wrap(item, width: 50, first: "1. ", rest: "   ") + "\n" + wrap(item, width: 50, first: "2. ", rest: "   ")
        #expect(HardWrapCleaner.clean(text) == "1. " + item + "\n2. " + item)
    }

    @Test func chineseHasNoInsertedSpaces() {
        let zh = "終端機依視窗寬度自動換行，這些視覺換行被當成真正的換行字元複製出去，貼到會自動重排的地方就變成一堆斷斷續續的短行，看起來非常凌亂。"
        let wrapped = wrapCJK(zh, width: 50, first: "⏺ ", rest: "  ")
        #expect(wrapped.contains("\n"))
        #expect(HardWrapCleaner.clean(wrapped) == "⏺ " + zh)
    }

    @Test func chineseThenEnglishKeepsSwallowedSpace() {
        // The wrap fell on the space between "有" and "NoMess".
        let text = """
          這段中文也是刻意用硬換行切開的，模擬終端機依視窗寬度把長句
          子切斷的情況。沒有 NoMess 時貼上會變成好幾行短句；有
          NoMess 時應該接回成完整的一段。
        """
        #expect(HardWrapCleaner.clean(text) == "  這段中文也是刻意用硬換行切開的，模擬終端機依視窗寬度把長句子切斷的情況。沒有 NoMess 時貼上會變成好幾行短句；有 NoMess 時應該接回成完整的一段。")
    }

    @Test func selectionStartedAfterMarker() {
        // Copied from "This…", leaving "⏺ " behind; continuation lines keep their indent.
        let wrapped = wrap(prose, width: 60, first: "⏺ ", rest: "  ")
        let clipped = String(wrapped.dropFirst(2))
        #expect(HardWrapCleaner.clean(clipped) == prose)
    }

    @Test func headingAndQuoteAreNotSwallowed() {
        let body = wrap(prose, width: 50)
        let text = "# Notes\n" + body + "\n> quoted line that follows the paragraph"
        #expect(HardWrapCleaner.clean(text) == "# Notes\n" + prose + "\n> quoted line that follows the paragraph")
    }

    @Test func windowsLineEndings() {
        let wrapped = wrap(prose, width: 50).replacingOccurrences(of: "\n", with: "\r\n")
        #expect(HardWrapCleaner.clean(wrapped) == prose)
    }
}

@Suite struct LeavesAlone {
    @Test func singleLine() {
        #expect(HardWrapCleaner.clean(prose) == nil)
    }

    @Test func narrowText() {
        #expect(HardWrapCleaner.clean("hello there\nthis is short\nand narrow") == nil)
    }

    @Test func oneLongLineThenShortLine() {
        let text = "Build complete! Compiled forty modules in three seconds total\nwarnings none"
        #expect(HardWrapCleaner.clean(text) == nil)
    }

    @Test func codeFence() {
        let code = "```swift\nlet cleaner = HardWrapCleaner.clean(pasteboardContents ?? \"\")\nprint(cleaner)\n```"
        #expect(HardWrapCleaner.clean(code) == nil)
    }

    @Test func codeLines() {
        let code = """
        func poll() { guard changeCount != lastChangeCount else { return } {
            lastChangeCount = changeCount; let frontmost = workspace.frontmost;
            guard TerminalApps.contains(frontmost) else { return nil } x = 1;
        }
        """
        #expect(HardWrapCleaner.clean(code) == nil)
    }

    @Test func logLines() {
        let log = """
        2026-10-04 12:00:01 INFO pasteboard changed, frontmost app is Terminal
        2026-10-04 12:00:02 INFO cleaned three hard wraps and wrote back result
        2026-10-04 12:00:03 INFO pasteboard changed, frontmost app is Safari ok
        """
        #expect(HardWrapCleaner.clean(log) == nil)
    }

    @Test func alignedTable() {
        let table = """
        NAME            STATUS      AGE     DESCRIPTION OF THE THING
        nomess-api      Running     3d      handles requests from clients
        nomess-worker   Running     3d      processes the background queue
        """
        #expect(HardWrapCleaner.clean(table) == nil)
    }

    @Test func boxTable() {
        let table = """
        ┌──────────────────┬──────────────────────────────────┐
        │ Product          │ What it does for the user here   │
        │ clip.md          │ converts rich text to markdown   │
        └──────────────────┴──────────────────────────────────┘
        """
        #expect(HardWrapCleaner.clean(table) == nil)
    }

    @Test func fileList() {
        let files = """
        Sources/NoMessCore/HardWrapCleaner.swift
        Sources/NoMessCore/DisplayWidth.swift
        Sources/NoMess/PasteboardWatcher.swift
        """
        #expect(HardWrapCleaner.clean(files) == nil)
    }

    @Test func linePerSentence() {
        let text = """
        The watcher polls the pasteboard change count every few hundred ms.
        Nothing is read unless the frontmost application is a terminal one.
        """
        #expect(HardWrapCleaner.clean(text) == nil)
    }

    @Test func unindentedLineThenIndentedBlock() {
        // A short heading over an indented block of records is not a clipped wrap.
        let text = """
        Nightly build results
          Everything passed on the first try without any retries.
          The artifact was uploaded to the release bucket as usual.
        """
        #expect(HardWrapCleaner.clean(text) == nil)
    }

    @Test func shellSession() {
        let text = """
        $ swift build --configuration release --product NoMess --verbose
        $ open build/NoMess.app and then copy something from the terminal
        """
        #expect(HardWrapCleaner.clean(text) == nil)
    }
}
