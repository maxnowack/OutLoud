import AppKit
import SwiftUI

/// Opens the setup and history windows. A menu bar app has no window of its own and is not
/// active, so each window brings the app forward when it opens.
@MainActor
final class WindowManager {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(
        _ id: String, title: String, size: NSSize, resizable: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if let window = windows[id] {
            bringForward(window)
            return
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered,
            defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content())
        window.center()
        window.setFrameAutosaveName("Outloud.\(id)")
        windows[id] = window
        bringForward(window)
    }

    /// Activates the app, then puts the window in front of every app's windows: a window
    /// ordered front while the app is inactive stays behind the app in front, and a menu bar
    /// app is inactive whenever its menu was used from another app.
    private func bringForward(_ window: NSWindow) {
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKey()
    }

    func close(_ id: String) {
        windows[id]?.close()
    }
}
