import AppKit
import OutloudKit
import OutloudUI
import SwiftUI

/// The panel under the menu bar icon (`docs/DESIGN.md` §"Screens": macOS menu bar panel).
struct MenuBarPanel: View {
    let app: AppModel
    let showSetup: () -> Void
    let showHistory: () -> Void
    /// The kept result shown; `nil` for the newest.
    @State private var shown: HistoryEntry.ID?
    @FocusState private var focused: Bool

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

            PasteQueue(
                items: app.pendingPastes.map { .init(id: $0.ticket, app: $0.app, text: $0.text) }
            ) { app.removePending($0.id) }

            let entries = app.history.entries
            if let index = shownIndex, index < entries.count {
                VStack(spacing: Tokens.Spacing.s) {
                    ResultPager(
                        position: index + 1, count: entries.count, date: entries[index].createdAt,
                        older: older, newer: newer)
                    // A card of its own per entry, so that "Copied" does not carry over.
                    ResultCard(outcome: app.outcome(of: entries[index]))
                        .id(entries[index].id)
                }
            } else if let outcome = app.lastOutcome {
                // The history keeps nothing.
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
        // Takes the keys, so that ← and → step through the results.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.leftArrow) {
            newer()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            older()
            return .handled
        }
        .onAppear {
            shown = nil
            focused = true
            app.refreshAccessibility()
        }
    }

    /// Where the shown entry is in the history, newest first; `nil` while it keeps nothing.
    private var shownIndex: Int? {
        let entries = app.history.entries
        guard !entries.isEmpty else { return nil }
        return shown.flatMap { id in entries.firstIndex { $0.id == id } } ?? 0
    }

    private func older() {
        let entries = app.history.entries
        guard let index = shownIndex, index + 1 < entries.count else { return }
        shown = entries[index + 1].id
    }

    private func newer() {
        let entries = app.history.entries
        guard let index = shownIndex, index > 0 else { return }
        // Back at the newest, the panel follows the next result again.
        shown = index == 1 ? nil : entries[index - 1].id
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
