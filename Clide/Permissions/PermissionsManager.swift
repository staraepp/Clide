import AVFoundation
import AppKit
import ApplicationServices

/// Status of a single OS-level permission Clide depends on.
enum PermissionStatus: Equatable {
    case notDetermined
    case granted
    case denied
}

/// Requests and reports on the two permissions the sacred path needs:
/// microphone capture and Accessibility (for text insertion into other apps).
@MainActor
enum PermissionsManager {
    static func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// Shows the system microphone permission prompt if not yet determined.
    static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// Prompts the user to grant Accessibility permission in System Settings
    /// if it hasn't been granted yet. Returns the current trust state.
    /// Shows the system Accessibility prompt.
    ///
    /// Only call this in response to something the user just did. macOS shows
    /// the dialog every single time this runs while untrusted, so calling it
    /// on a timer, at launch, or on each dictation attempt nags relentlessly —
    /// especially with ad-hoc signed development builds, where every rebuild
    /// invalidates the existing grant. Use `accessibilityStatus()` to check.
    @discardableResult
    static func promptForAccessibilityAccess() -> Bool {
        // Using the documented key string directly rather than the SDK's
        // `kAXTrustedCheckOptionPrompt` global, which is imported as
        // `Unmanaged<CFString>!` and trips strict-concurrency's shared
        // mutable state check even though it never actually changes.
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openMicrophoneSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
