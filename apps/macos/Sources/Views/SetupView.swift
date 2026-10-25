import OutloudKit
import OutloudUI
import SwiftUI

/// The first launch (`docs/DESIGN.md` §"Screens": macOS setup window).
struct SetupView: View {
    let app: AppModel
    let finish: () -> Void
    /// Preselected: a dictation app in the menu bar is meant to be ready after a restart.
    @State private var openAtLogin = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                ModelSetup(library: app.library, settings: app.settings, network: app.network) {
                    if openAtLogin != app.loginItem.isEnabled {
                        app.loginItem.setEnabled(openAtLogin)
                    }
                    finish()
                }
                Divider()
                VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                    Text("Dictating").font(Tokens.heading)
                    Text(
                        "Hold \(app.activeHotkey?.title ?? app.hotkey.title) anywhere, speak, and release. Outloud asks for the microphone once. To paste into the active text field automatically, it also needs Accessibility access; without it, the result is copied to the clipboard."
                    )
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Toggle("Open Outloud at login", isOn: $openAtLogin)
            }
            .padding(Tokens.Spacing.xl)
        }
        .task { await app.library.refresh() }
    }
}
