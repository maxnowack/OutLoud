import AppKit
import OutloudKit
import OutloudUI
import SwiftUI

/// The panel under the menu bar icon (`docs/DESIGN.md` §"Screens": macOS menu bar panel).
struct MenuBarPanel: View {
    let app: AppModel
    let showSetup: () -> Void
    let showHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            StatusIndicator(state: app.dictation.state)

            if app.needsSetup {
                Text("Outloud needs its models before you can dictate.")
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                Button("Set Up Outloud…", action: showSetup)
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.accentFill)
            } else if app.hotkeyAvailable {
                Text(
                    "Hold \(app.activeHotkey?.title ?? app.hotkey.title) to dictate, release it to paste."
                )
                .font(Tokens.detail)
                .foregroundStyle(Tokens.textSecondary)
            } else {
                Label(
                    "\(app.hotkey.title) is used by another app. Choose another shortcut in Settings.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(Tokens.detail)
                .foregroundStyle(Tokens.warning)
            }

            if case .failed(let failure) = app.dictation.state {
                FailureNotice(failure: failure) { failure in
                    switch failure {
                    case .microphoneDenied: SystemSettings.openMicrophone()
                    case .modelsMissing: showSetup()
                    default: break
                    }
                }
            }

            if let outcome = app.lastOutcome {
                ResultCard(outcome: outcome)
            }

            if app.autoPasteEnabled && !app.accessibilityTrusted && !app.needsSetup {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text("To paste automatically, Outloud needs Accessibility access.")
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                    Button("Allow Accessibility…") { app.requestAccessibility() }
                        .controlSize(.small)
                }
            }

            Divider()

            // The rest — Settings, updates, Quit — is in the icon's right-click menu.
            Button("History…", action: showHistory)
                .buttonStyle(.bordered)
        }
        .padding(Tokens.Spacing.l)
        .frame(width: 340)
        .onAppear { app.refreshAccessibility() }
    }
}

enum SystemSettings {
    static func openMicrophone() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
