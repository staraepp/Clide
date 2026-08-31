import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dictationCoordinator: DictationCoordinator?
    private let dashboardWindowController = DashboardWindowController()
    private let onboardingWindowController = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        let coordinator = DictationCoordinator()
        dictationCoordinator = coordinator

        if OnboardingState.hasCompleted {
            // No permission prompts here on purpose — see requestPermissions
            // note below. Clide has no Dock icon, so without showing something
            // launching it looks like nothing happened. Once launch-at-login is
            // common this should skip login launches.
            dashboardWindowController.show()
        } else {
            // Onboarding asks for each permission in context, so don't fire the
            // system prompts before the user has been told what they're for.
            onboardingWindowController.show(coordinator: coordinator) { [weak self] in
                self?.dashboardWindowController.show()
            }
        }
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

    // Clide deliberately asks for no permissions at launch.
    //
    // Both prompts nag on every start otherwise: development builds are
    // ad-hoc signed, so each rebuild is a new app to TCC — microphone access
    // reverts to "not determined" and Accessibility to untrusted, even though
    // System Settings still lists Clide. Prompting at launch then fires the
    // dialogs again every single time.
    //
    // Permissions are requested where the user has just asked for something
    // that needs them: the onboarding steps, and the first dictation attempt.
}
