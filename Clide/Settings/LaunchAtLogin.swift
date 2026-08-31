import ServiceManagement

/// Launch-at-login via the modern SMAppService API (clide.md §29).
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            apply(isEnabled)
        }
    }

    /// Set when macOS has the login item registered but the user still has to
    /// approve it in System Settings.
    @Published private(set) var needsApproval = false

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    private func apply(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail for an unsigned or relocated build; reflect
            // reality rather than leaving the toggle showing a state that isn't true.
            isEnabled = SMAppService.mainApp.status == .enabled
        }
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }
}
