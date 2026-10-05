import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let enabledKey = "enabled"

    private let watcher = PasteboardWatcher()
    private var statusItem: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "啟用 NoMess", action: #selector(toggle), keyEquivalent: "")

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "結束 NoMess", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        apply()
    }

    @objc private func toggle() {
        isEnabled.toggle()
        apply()
    }

    private func apply() {
        if isEnabled { watcher.start() } else { watcher.stop() }
        toggleItem.state = isEnabled ? .on : .off

        let symbol = isEnabled ? "text.justify.left" : "pause.circle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NoMess")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !isEnabled
    }
}
