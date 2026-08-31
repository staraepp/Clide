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

        if let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.isOptionDown = event.modifierFlags.contains(.option)
            return event
        } {
            monitors.append(flagsMonitor)
        }

        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard event.keyCode == Self.periodKeyCode else { return event }
            self?.isPeriodDown = (event.type == .keyDown)
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
