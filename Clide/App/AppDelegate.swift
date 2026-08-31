import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dictationCoordinator: DictationCoordinator?
    private let dashboardWindowController = DashboardWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        dictationCoordinator = DictationCoordinator()
        requestPermissionsIfNeeded()

        // Clide has no Dock icon, so without this, launching it looks like
        // nothing happened. Once launch-at-login exists this needs to skip
        // login launches.
        dashboardWindowController.show()
    }

    /// Clicking the app in Finder/Spotlight while it's already running should
    /// bring the dashboard back rather than silently doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        dashboardWindowController.show()
        return true
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Clide")

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Clide 0.2", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Clide", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clide", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openDashboard() {
        dashboardWindowController.show()
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
