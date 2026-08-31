import AppKit
import SwiftUI

/// Floating, non-activating panel that shows dictation status without ever
/// stealing keyboard focus from whatever app the user is dictating into.
@MainActor
final class DictationPillWindow {
    private let panel: NSPanel
    private let hostingView: NSHostingView<DictationPillView>
    private let amplitude = WaveformAmplitudeModel()
    private var hideAfterAnimationTask: Task<Void, Never>?

    /// Long enough for the SwiftUI exit transition to finish before the window
    /// is ordered out — otherwise the pill vanishes instead of animating away.
    private static let exitAnimationDuration: Duration = .milliseconds(320)

    /// Sized generously so the pill can grow into it without the window
    /// clipping mid-animation; the panel itself is transparent.
    private static let canvasSize = NSSize(width: 620, height: 90)

    init() {
        hostingView = NSHostingView(rootView: DictationPillView(state: .idle, amplitude: amplitude))
        hostingView.frame = NSRect(origin: .zero, size: Self.canvasSize)

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
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
    }

    /// Drives a real state transition. Amplitude ticks don't come through here —
    /// they flow reactively via the shared `amplitude` model instead.
    func present(state: PillState, choiceActions: PillChoiceActions? = nil) {
        hideAfterAnimationTask?.cancel()
        hostingView.rootView = DictationPillView(
            state: state,
            amplitude: amplitude,
            choiceActions: choiceActions
        )
        panel.ignoresMouseEvents = !state.isInteractive

        if state.isVisible {
            reposition()
            panel.orderFrontRegardless()
        } else {
            // Keep the window on screen until the exit transition has played.
            hideAfterAnimationTask = Task { [panel] in
                try? await Task.sleep(for: Self.exitAnimationDuration)
                guard !Task.isCancelled else { return }
                panel.orderOut(nil)
            }
        }
    }

    func updateAmplitude(_ level: Float) {
        amplitude.level = level
    }

    /// Centred near the top of the active screen, out of the way of the text
    /// the user is dictating into.
    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: visible.midX - Self.canvasSize.width / 2,
                y: visible.maxY - Self.canvasSize.height - 40,
                width: Self.canvasSize.width,
                height: Self.canvasSize.height
            ),
            display: true
        )
    }
}
