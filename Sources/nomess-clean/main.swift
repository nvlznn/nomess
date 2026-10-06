// Runs the same cleaner the app uses on stdin, for trying real cases:
//   pbpaste | swift run nomess-clean          # cleaned plain text
//   pbpaste | swift run nomess-clean --html   # HTML copy offered for diagrams
// When the cleaner leaves the input alone, it is printed unchanged and a note
// goes to stderr.
import Foundation
import NoMessCore

let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
let cleaned = HardWrapCleaner.clean(input)
let realigned = DiagramDetector.restoringClippedFirstLine(cleaned ?? input)
let text = realigned ?? cleaned

func note(_ message: String) {
    FileHandle.standardError.write(Data("nomess: \(message)\n".utf8))
}

if CommandLine.arguments.contains("--html") {
    if let blocks = DiagramDetector.blocks(text ?? input) {
        print(RichText.html(blocks))
    } else {
        note("no diagrams detected, no HTML copy")
    }
} else if let text {
    print(text, terminator: "")
} else {
    note("nothing to fix, unchanged")
    print(input, terminator: "")
}
