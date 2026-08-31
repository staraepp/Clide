import AppKit
import ApplicationServices

enum InsertionOutcome: Equatable {
    case insertedDirectly
    /// Direct insertion didn't work for this field, so Clide pasted instead.
    case copiedAfterInsertionFailed
    /// Nothing editable was focused, so there was nowhere to insert.
    case copiedUnsupportedField
    /// Accessibility isn't granted, so Clide could neither type nor paste.
    case copiedNeedsAccessibility
    case secureFieldBlocked
    case failed(String)
}

/// Inserts transcribed text into whichever UI element is currently focused,
/// preferring direct Accessibility insertion and falling back to a clipboard
/// paste when that isn't possible. Never inserts into secure fields.
@MainActor
enum TextInsertionService {
    static func insert(_ text: String) -> InsertionOutcome {
        guard !text.isEmpty else { return .failed("Nothing to insert") }

        // Both the Accessibility path and the synthetic ⌘V of the clipboard
        // fallback need this permission, so without it the useful thing Clide
        // can still do is leave the transcript on the clipboard to paste by hand.
        guard AXIsProcessTrusted() else {
            copyToClipboard(text)
            return .copiedNeedsAccessibility
        }

        guard let focusedElement = focusedUIElement() else {
            return pasteViaClipboard(text, outcome: .copiedUnsupportedField)
        }

        if isSecureField(focusedElement) {
            return .secureFieldBlocked
        }

        if setSelectedText(text, on: focusedElement) {
            return .insertedDirectly
        }

        return pasteViaClipboard(text, outcome: .copiedAfterInsertionFailed)
    }

    // MARK: - Accessibility

    private static func focusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func isSecureField(_ element: AXUIElement) -> Bool {
        stringAttribute(kAXSubroleAttribute, of: element) == (kAXSecureTextFieldSubrole as String)
            || stringAttribute(kAXRoleAttribute, of: element) == (kAXSecureTextFieldSubrole as String)
    }

    private static func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? String
    }

    private static func setSelectedText(_ text: String, on element: AXUIElement) -> Bool {
        // Only attempt direct insertion when the element reports it's settable —
        // otherwise AXUIElementSetAttributeValue silently no-ops on many apps.
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue else { return false }

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    // MARK: - Clipboard fallback

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func pasteViaClipboard(_ text: String, outcome: InsertionOutcome) -> InsertionOutcome {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let pasted = synthesizePaste()

        // Restore whatever was on the clipboard before, but only if the user
        // hasn't already overwritten it with something new in the meantime.
        if pasted, let previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if pasteboard.string(forType: .string) == text {
                    pasteboard.clearContents()
                    pasteboard.setString(previousContents, forType: .string)
                }
            }
        }

        return pasted ? outcome : .failed("Clide couldn't paste the transcript.")
    }

    private static func synthesizePaste() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return true
    }
}
