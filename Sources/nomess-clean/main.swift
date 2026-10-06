// Runs the same cleaner the app uses on stdin, for trying real cases:
//   pbpaste | swift run nomess-clean          # cleaned plain text
//   pbpaste | swift run nomess-clean --html       # HTML copy offered for diagrams
//   pbpaste | swift run nomess-clean --markdown   # what chat apps get (``` fences)
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

let arguments = CommandLine.arguments
if arguments.contains("--html") || arguments.contains("--markdown") {
    if let blocks = DiagramDetector.blocks(text ?? input) {
        let metrics = CoreTextMetrics.menlo()
        print(arguments.contains("--html") ? RichText.html(blocks, metrics: metrics) : RichText.markdown(blocks, metrics: metrics))
    } else {
        note("no diagrams detected, nothing different to offer")
    }
} else if let text {
    print(text, terminator: "")
} else {
    note("nothing to fix, unchanged")
    print(input, terminator: "")
}
