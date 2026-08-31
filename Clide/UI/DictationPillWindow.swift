import AppKit
import SwiftUI

/// Floating, non-activating panel that shows dictation status without ever
/// stealing keyboard focus from whatever app the user is dictating into.
@MainActor
final class DictationPillWindow {
    private let panel: NSPanel
    private let hostingView: NSHostingView<DictationPillView>

    init() {
        let initialView = DictationPillView(state: .idle)
        hostingView = NSHostingView(rootView: initialView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 40)

        panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
    }

    func update(state: PillState) {
        hostingView.rootView = DictationPillView(state: state)
        resizeToFitAndReposition()
        state.isVisible ? show() : hide()
    }

    private func resizeToFitAndReposition() {
        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        var frame = panel.frame
        frame.size = fittingSize
        panel.setFrame(frame, display: true)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.maxY - frame.height - 60
        )
        panel.setFrameOrigin(origin)
    }

    private func show() {
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel.orderOut(nil)
    }
}
