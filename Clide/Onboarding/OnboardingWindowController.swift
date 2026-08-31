import AppKit
import SwiftUI

/// Hosts onboarding in its own fixed-size window.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var state: OnboardingState?

    func show(coordinator: DictationCoordinator, onFinish: @escaping () -> Void) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingState = OnboardingState(coordinator: coordinator)
        state = onboardingState

        let rootView = OnboardingView(state: onboardingState) { [weak self] in
            onboardingState.finish()
            self?.close()
            onFinish()
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to Clide"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(rootView: rootView)
        newWindow.center()

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() {
        window?.close()
        window = nil
        state = nil
    }
}
