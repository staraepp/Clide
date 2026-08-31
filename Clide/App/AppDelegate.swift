import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dictationCoordinator: DictationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        dictationCoordinator = DictationCoordinator()
        requestPermissionsIfNeeded()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Clide")

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Clide 0.2", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clide", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func requestPermissionsIfNeeded() {
        if PermissionsManager.microphoneStatus() == .notDetermined {
            Task { await PermissionsManager.requestMicrophoneAccess() }
        }
        if PermissionsManager.accessibilityStatus() != .granted {
            PermissionsManager.requestAccessibilityAccess()
        }
    }
}
