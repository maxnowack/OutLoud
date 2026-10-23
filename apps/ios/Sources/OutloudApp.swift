import OutloudKit
import OutloudUI
import SwiftUI

/// The iOS app (ADR 0003).
@main
struct OutloudApp: App {
    @State private var app = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
                .tint(Tokens.accent)
                .task { await app.start() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await app.library.refresh()
                        await app.history.refresh()
                    }
                }
        }
    }
}

struct RootView: View {
    enum Screen: String { case dictate, history, settings }

    let app: AppModel
    // `-OutloudTab history` opens another tab first, for the end-to-end test plans.
    @State private var screen =
        UserDefaults.standard.string(forKey: "OutloudTab").flatMap(Screen.init(rawValue:))
        ?? .dictate

    var body: some View {
        Group {
            if app.settings.hasCompletedSetup {
                TabView(selection: $screen) {
                    Tab("Dictate", systemImage: "mic", value: .dictate) { DictateScreen(app: app) }
                    Tab("History", systemImage: "clock", value: .history) {
                        HistoryScreen(app: app)
                    }
                    Tab("Settings", systemImage: "gearshape", value: .settings) {
                        SettingsScreen(app: app)
                    }
                }
            } else {
                SetupScreen(app: app)
            }
        }
    }
}
