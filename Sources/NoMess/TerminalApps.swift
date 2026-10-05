/// Apps whose copies are treated as terminal output. Claude Code runs inside
/// one of these, so it is covered too. Editors with a built-in terminal
/// (VS Code, Cursor) are left out on purpose: most of what is copied there is
/// code, and V0 cannot tell the two apart.
enum TerminalApps {
    static let bundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "com.github.wez.wezterm",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "dev.warp.Warp-Stable",
        "com.stablyai.orca",
    ]

    static func contains(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }
}
