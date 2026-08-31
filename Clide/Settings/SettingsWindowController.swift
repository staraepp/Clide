import AppKit
import SwiftUI

/// Hosts Settings in its own window.
///
/// SwiftUI's automatic `Settings { }` scene relies on `NSApp.sendAction(_:
/// "showSettingsWindow:", ...)` reaching a responder that implements it —
/// which is wired up as part of the standard app menu SwiftUI builds
/// automatically. Clide is `LSUIElement` (no Dock icon, no standard menu
/// bar), so that bridge never gets built and the selector send silently
/// does nothing: confirmed by actually clicking "Settings…" and the gear
/// icon and finding neither opened anything. A manually-owned window,
/// matching how Dashboard and Onboarding already work in this app, sidesteps
/// the missing bridge entirely.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Settings"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        // Without a bounded height the Form has nothing to scroll inside and
        // grows to fit every section at once — it measured out to 1755pt tall
        // (taller than most displays) before this was added.
        newWindow.minSize = NSSize(width: 470, height: 420)
        newWindow.maxSize = NSSize(width: 470, height: 760)
        newWindow.contentView = NSHostingView(rootView: SettingsView())
        newWindow.center()
        newWindow.setFrameAutosaveName("ClideSettings")

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
