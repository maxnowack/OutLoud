import AppKit
import ApplicationServices

/// Hands a result to the app the user is typing in (ADR 0004).
///
/// With the Accessibility access granted and a text field focused, the result is pasted with a
/// simulated ⌘V and the clipboard is restored afterwards. Otherwise the result stays on the
/// clipboard for pasting by hand.
@MainActor
enum AutoPaster {
    enum Delivery: Equatable {
        case pasted
        case copied(Reason)

        enum Reason: Equatable {
            case autoPasteOff
            case noPermission
            case noTextField
        }
    }

    /// Whether the user has granted the Accessibility access auto-paste needs.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks macOS to show its Accessibility prompt for Outloud.
    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func deliver(_ text: String, autoPaste: Bool) async -> Delivery {
        guard autoPaste else { return copy(text, .autoPasteOff) }
        guard isTrusted else { return copy(text, .noPermission) }
        guard focusedElementAcceptsText() else { return copy(text, .noTextField) }

        let pasteboard = NSPasteboard.general
        let saved = savedItems(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount
        postCommandV()
        // The target reads the clipboard asynchronously; restore it only after it had time, and
        // only if nothing else wrote to it meanwhile.
        try? await Task.sleep(for: .milliseconds(600))
        if pasteboard.changeCount == changeCount, !saved.isEmpty {
            pasteboard.clearContents()
            pasteboard.writeObjects(saved)
        }
        return .pasted
    }

    private static func copy(_ text: String, _ reason: Delivery.Reason) -> Delivery {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return .copied(reason)
    }

    private static func savedItems(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV = CGKeyCode(9)  // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Whether the focused element takes typed text. Protected (password) fields do not count.
    static func focusedElementAcceptsText() -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                system, kAXFocusedUIElementAttribute as CFString, &focused)
                == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        let element = focused as! AXUIElement
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        if (subrole as? String) == (kAXSecureTextFieldSubrole as String) { return false }
        let textRoles: Set<String> = [
            kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String,
            "AXSearchField",
        ]
        if let role = role as? String, textRoles.contains(role) { return true }
        // Web content and custom editors expose a settable value or a text selection.
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
            == .success, settable.boolValue
        {
            return true
        }
        var range: CFTypeRef?
        return AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &range) == .success
    }
}
