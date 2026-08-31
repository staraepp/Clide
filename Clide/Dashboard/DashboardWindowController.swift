import AppKit
import SwiftUI

/// Hosts the dashboard in a normal, resizable Mac window. Built in AppKit
/// because Clide is an LSUIElement app driven from the menu bar, so windows
/// are opened imperatively rather than through a SwiftUI scene.
@MainActor
final class DashboardWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Clide"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 460, height: 420)
        newWindow.contentView = NSHostingView(rootView: DashboardView())
        newWindow.center()
        newWindow.setFrameAutosaveName("ClideDashboard")

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
