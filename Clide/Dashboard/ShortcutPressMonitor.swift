import AppKit

/// Tracks whether the dictation shortcut's keys are physically down, so the
/// dashboard keycaps react to real presses.
///
/// Uses local monitors only — these fire while a Clide window has focus and
/// need no special permission. The global hotkey itself is handled separately
/// by KeyboardShortcuts; this is purely visual feedback.
@MainActor
final class ShortcutPressMonitor: ObservableObject {
    @Published private(set) var isOptionDown = false
    @Published private(set) var isPeriodDown = false

    private var monitors: [Any] = []

    private static let periodKeyCode: UInt16 = 47

    func start() {
        guard monitors.isEmpty else { return }

        // NSEvent's monitor closure isn't statically @MainActor, even though
        // AppKit only ever calls it on the main thread. Touching a
        // MainActor-isolated @Published property directly from inside it hits
        // a Swift concurrency runtime crash (a bad executor-identity check in
        // swift_task_isCurrentExecutorWithFlagsImpl) on this toolchain — see
        // the crash report from the first real run of this screen. Routing
        // the mutation through DispatchQueue.main.async sidesteps that
        // runtime path entirely; a one-frame-later keycap highlight is
        // imperceptible.
        if let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let isDown = event.modifierFlags.contains(.option)
            DispatchQueue.main.async { self?.isOptionDown = isDown }
            return event
        } {
            monitors.append(flagsMonitor)
        }

        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard event.keyCode == Self.periodKeyCode else { return event }
            let isDown = event.type == .keyDown
            DispatchQueue.main.async { self?.isPeriodDown = isDown }
            return event
        } {
            monitors.append(keyMonitor)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isOptionDown = false
        isPeriodDown = false
    }
}
