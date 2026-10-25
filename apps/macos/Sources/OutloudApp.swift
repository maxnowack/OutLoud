import AppKit
import OutloudKit
import OutloudUI
import SwiftUI

/// The menu bar app (ADR 0004).
@main
struct OutloudApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The menu bar icon is an AppKit status item (`StatusItem`), and the settings open in a
        // window of their own; a SwiftUI app needs one scene all the same.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let app = AppModel()
    let windows = WindowManager()
    let updater = Updater()
    private var statusItem: StatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItem(
            app: app, updater: updater, showSetup: { [weak self] in self?.showSetup() },
            showHistory: { [weak self] in self?.showHistory() },
            showSettings: { [weak self] in self?.showSettings() })
        Task {
            await app.start()
            if app.needsSetup { showSetup() }
        }
    }

    func showSetup() {
        windows.show(
            "setup", title: String(localized: "Set Up Outloud"),
            size: NSSize(width: 560, height: 620),
            resizable: false
        ) {
            SetupView(app: app) { [weak self] in
                self?.windows.close("setup")
                Task { await self?.app.dictation.preloadModels() }
            }
        }
    }

    func showSettings() {
        windows.show(
            "settings", title: String(localized: "Settings"), size: NSSize(width: 520, height: 440),
            resizable: false
        ) {
            SettingsView(app: app)
        }
    }

    func showHistory() {
        windows.show(
            "history", title: String(localized: "History"), size: NSSize(width: 720, height: 480)
        ) {
            HistoryWindow(app: app)
        }
    }
}
