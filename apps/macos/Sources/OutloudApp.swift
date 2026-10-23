import AppKit
import OutloudKit
import OutloudUI
import SwiftUI

/// The menu bar app (ADR 0004).
@main
struct OutloudApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(
                app: delegate.app, showSetup: delegate.showSetup, showHistory: delegate.showHistory)
        } label: {
            MenuBarIcon(state: delegate.app.dictation.state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(app: delegate.app)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let app = AppModel()
    let windows = WindowManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await app.start()
            if app.needsSetup { showSetup() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        app.engines.unloadAll()
        QwenCleaner.shutDownBackend()
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

    func showHistory() {
        windows.show(
            "history", title: String(localized: "History"), size: NSSize(width: 720, height: 480)
        ) {
            HistoryWindow(app: app)
        }
    }
}

/// The menu bar icon follows the dictation state.
private struct MenuBarIcon: View {
    let state: DictationState

    var body: some View {
        switch state {
        case .recording: Image(systemName: "record.circle")
        case .transcribing, .cleaning: Image(systemName: "ellipsis.circle")
        case .failed: Image(systemName: "exclamationmark.circle")
        default: Image(systemName: "waveform")
        }
    }
}
