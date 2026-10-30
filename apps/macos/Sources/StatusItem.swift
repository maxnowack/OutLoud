import AppKit
import Observation
import OutloudKit
import SwiftUI

/// The menu bar icon: a click opens the panel, a right-click (or ⌃-click) the menu with
/// Settings, updates and Quit (`docs/DESIGN.md` §"Screens": macOS menu bar panel). SwiftUI's
/// `MenuBarExtra` cannot tell the two clicks apart, so this is an AppKit status item.
@MainActor
final class StatusItem: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let panel: NSHostingController<MenuBarPanel>
    private let app: AppModel
    private let updater: Updater
    private let showSettings: () -> Void
    /// The app that was active when the panel opened, which gets the activation back.
    private var previousApp: NSRunningApplication?

    init(
        app: AppModel, updater: Updater, showSetup: @escaping () -> Void,
        showHistory: @escaping () -> Void, showSettings: @escaping () -> Void
    ) {
        self.app = app
        self.updater = updater
        self.showSettings = showSettings
        var close: () -> Void = {}
        panel = NSHostingController(
            rootView: MenuBarPanel(
                app: app,
                showSetup: {
                    close()
                    showSetup()
                },
                showHistory: {
                    close()
                    showHistory()
                }))
        // The popover follows the size SwiftUI reports. Without it, it opened at a guessed height
        // and then shrank; AppKit keeps the bottom edge, so the arrow ended up below the icon.
        panel.sizingOptions = [.preferredContentSize]
        super.init()
        close = { [weak self] in self?.popover.performClose(nil) }
        popover.behavior = .transient
        popover.contentViewController = panel
        popover.delegate = self
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Outloud")
        }
        followState()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            // The size before it opens, so that it opens where it stays.
            popover.contentSize = panel.view.fittingSize
            // Active, so that the panel takes ← and →; the app in front gets it back on closing.
            if !NSApp.isActive { previousApp = NSWorkspace.shared.frontmostApplication }
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        popover.performClose(nil)
        let menu = NSMenu()
        menu.addItem(
            withTitle: String(localized: "Settings…"), action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        if updater.isAvailable {
            menu.addItem(
                withTitle: String(localized: "Check for Updates…"),
                action: #selector(checkForUpdates), keyEquivalent: ""
            ).target = self
        }
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Quit Outloud"), action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q")
        // A menu assigned for one click only: a permanent one would take the left click too.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openSettings() { showSettings() }
    @objc private func checkForUpdates() { updater.checkForUpdates() }

    /// Shows the dictation state, and whether dictations wait to be pasted, in the icon, and
    /// follows them.
    private func followState() {
        let (state, waiting) = withObservationTracking {
            (app.dictation.state, !app.pendingPastes.isEmpty)
        } onChange: { [weak self] in
            Task { @MainActor in self?.followState() }
        }
        let image = NSImage(
            systemSymbolName: Self.symbol(for: state, waiting: waiting),
            accessibilityDescription: nil)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.setAccessibilityValue(
            waiting ? String(localized: "Dictations wait to be pasted") : nil)
    }

    private static func symbol(for state: DictationState, waiting: Bool) -> String {
        switch state {
        case .recording: "record.circle"
        case .transcribing, .cleaning: "ellipsis.circle"
        case .failed: "exclamationmark.circle"
        default: waiting ? "clock" : "waveform"
        }
    }
}

extension StatusItem: NSPopoverDelegate {
    /// Hands the activation back to the app that had it before the panel opened — unless another
    /// app took it meanwhile, or a window of Outloud's opened from the panel.
    func popoverDidClose(_ notification: Notification) {
        guard let previous = previousApp else { return }
        previousApp = nil
        guard NSApp.isActive, !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain })
        else { return }
        _ = previous.activate(from: .current)
    }
}
