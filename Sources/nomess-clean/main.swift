// Runs the same cleaner the app uses on stdin, for trying real cases:
//   pbpaste | swift run nomess-clean
// Prints the cleaned text, or the input unchanged (and a note on stderr) when
// the cleaner decided to leave it alone.
import Foundation
import NoMessCore

let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)

if let cleaned = HardWrapCleaner.clean(input) {
    print(cleaned, terminator: "")
} else {
    FileHandle.standardError.write(Data("nomess: no hard wraps detected, unchanged\n".utf8))
    print(input, terminator: "")
}
