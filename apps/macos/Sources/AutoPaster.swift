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
        /// Waits until the user returns to the remembered field in the named app.
        case waiting(app: String)
        case copied(Reason)

        enum Reason: Equatable {
            case autoPasteOff
            case noPermission
            case noTextField
        }
    }

    /// A focused text field, for the dictation that follows it (`ReturnPaste`); equal when it is
    /// the same field showing the same content.
    struct Target: Equatable {
        let element: AXUIElement
        let pid: pid_t
        /// What tells this field from the same element showing other content: Electron apps
        /// keep one input across their sessions (`AutoPaster.identity(of:)`).
        let identity: [String]

        static func == (lhs: Target, rhs: Target) -> Bool {
            lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element) && lhs.identity == rhs.identity
        }
    }

    /// Whether the user has granted the Accessibility access auto-paste needs.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks macOS to show its Accessibility prompt for Outloud.
    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Reports `.pasted` as soon as the ⌘V is posted, when the text appears in the target; the
    /// clipboard is restored after that, in the background.
    static func deliver(_ text: String, autoPaste: Bool) -> Delivery {
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
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let pasteboard = NSPasteboard.general
            if pasteboard.changeCount == changeCount, !saved.isEmpty {
                pasteboard.clearContents()
                pasteboard.writeObjects(saved)
            }
        }
        return .pasted
    }

    /// Copies a result that is not pasted into the field in front, with the reason `deliver`
    /// would give.
    static func copy(_ text: String, autoPaste: Bool) -> Delivery {
        copy(text, !autoPaste ? .autoPasteOff : !isTrusted ? .noPermission : .noTextField)
    }

    /// The focused text field, when it takes text and is not a password field.
    static func focusedTarget() -> Target? {
        guard isTrusted, let element = focusedElement(), acceptsText(element) else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return Target(element: element, pid: pid, identity: identity(of: element))
    }

    /// The text field focused in the app `pid` while that app is in front — `nil` when another
    /// app is in front, or the focused element takes no text or is a password field, so that a
    /// paste on return never lands elsewhere (ADR 0026, ADR 0027).
    static func focusedTarget(in pid: pid_t) -> Target? {
        guard isTrusted, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        else { return nil }
        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute as CFString,
                &focused) == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement
        guard acceptsText(element) else { return nil }
        return Target(element: element, pid: pid, identity: identity(of: element))
    }

    /// The window's title, the element's identifiers and, inside web content, the page's title
    /// and address — what changes when an app shows another conversation in the same field.
    private static func identity(of element: AXUIElement) -> [String] {
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &window)
        let windowTitle =
            (window.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? $0 : nil })
            .map { attribute(kAXTitleAttribute, of: $0 as! AXUIElement) ?? "" } ?? ""
        var parts = [
            windowTitle,
            attribute(kAXIdentifierAttribute, of: element) ?? "",
            attribute("AXDOMIdentifier", of: element) ?? "",
        ]
        // The nearest web area above the field: its page.
        var current = element
        for _ in 0..<40 {
            var parent: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
                    == .success, let parent, CFGetTypeID(parent) == AXUIElementGetTypeID()
            else { break }
            current = parent as! AXUIElement
            if attribute(kAXRoleAttribute, of: current) == "AXWebArea" {
                var url: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXURLAttribute as CFString, &url)
                parts += [
                    attribute(kAXTitleAttribute, of: current) ?? "",
                    (url as? URL)?.absoluteString ?? "",
                ]
                break
            }
        }
        return parts
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value as? String
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
        focusedElement().map(acceptsText) ?? false
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                system, kAXFocusedUIElementAttribute as CFString, &focused)
                == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        return (focused as! AXUIElement)
    }

    private static func acceptsText(_ element: AXUIElement) -> Bool {
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
