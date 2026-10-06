/// Apps where the exact plain text matters more than looks. Together with the
/// terminals, they get diagrams unchanged; everywhere else gets diagrams
/// wrapped in ``` so Markdown-aware chat apps show them monospaced.
enum CodeEditors {
    static let bundleIdentifiers: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.zed.Zed",
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "com.apple.TextEdit",
    ]

    static func contains(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
            || bundleIdentifier.hasPrefix("com.jetbrains.")
    }
}

enum PlainTextDestinations {
    static func contains(_ bundleIdentifier: String?) -> Bool {
        TerminalApps.contains(bundleIdentifier) || CodeEditors.contains(bundleIdentifier)
    }
}

/// Which version of a copy with diagrams an app should get.
enum DiagramVariant {
    /// Terminals and editors: the text exactly as copied.
    case original
    /// Apple Notes: HTML whose diagrams are spaced for Notes' monostyled font.
    case notes
    /// Everything else: diagrams fenced as ``` in the plain text.
    case fenced

    static func `for`(_ bundleIdentifier: String?) -> DiagramVariant {
        if PlainTextDestinations.contains(bundleIdentifier) { return .original }
        if bundleIdentifier == "com.apple.Notes" { return .notes }
        return .fenced
    }
}
