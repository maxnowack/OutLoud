import OutloudKit
import OutloudUI
import SwiftUI

/// The settings window (`docs/DESIGN.md` §"Screens": macOS settings window).
struct SettingsView: View {
    let app: AppModel

    var body: some View {
        TabView {
            GeneralSettings(app: app)
                .tabItem { Label("General", systemImage: "gearshape") }
            ModelSettings(app: app)
                .tabItem { Label("Models", systemImage: "cpu") }
            HistorySettings(app: app)
                .tabItem { Label("History", systemImage: "clock") }
            PrivacySettings(app: app)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 520, height: 440)
    }
}

private struct GeneralSettings: View {
    @Bindable var app: AppModel
    @State private var cleanup = CleanupAvailability.current

    var body: some View {
        Form {
            Section {
                Picker("Push-to-talk shortcut", selection: $app.hotkey) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                if !app.hotkeyAvailable {
                    Label(
                        "This shortcut is used by another app. Choose another one.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(Tokens.warning)
                }
                if app.hotkeyFallsBack {
                    HStack {
                        Label(
                            "\(HotkeyPreset.optionCommand.title) needs Accessibility access. Until it is allowed, hold \(HotkeyPreset.fallback.title).",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(Tokens.warning)
                        Spacer()
                        Button("Allow…") { app.requestAccessibility() }
                    }
                }
            } footer: {
                Text("Hold the shortcut while you speak; Outloud transcribes when you release it.")
            }

            Section {
                Toggle(
                    "Clean up the transcript",
                    isOn: Binding(
                        get: { app.settings.cleanupEnabled && cleanup == .available },
                        set: { app.settings.cleanupEnabled = $0 })
                )
                .disabled(cleanup != .available)
            } footer: {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                    Text(
                        "Removes filler words, fixes punctuation and sets paragraphs, without changing what you said."
                    )
                    CleanupAvailabilityNote(availability: cleanup)
                }
            }

            Section {
                Toggle("Paste into the active text field", isOn: $app.autoPasteEnabled)
                if app.autoPasteEnabled {
                    LabeledContent("Accessibility access") {
                        if app.accessibilityTrusted {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Tokens.success)
                        } else {
                            Button("Allow…") { app.requestAccessibility() }
                        }
                    }
                }
            } footer: {
                Text(
                    "Without it, or when no text field is focused, the result stays on the clipboard for pasting with ⌘V."
                )
            }
        }
        .formStyle(.grouped)
        .trackingCleanupAvailability($cleanup)
        .onAppear { app.refreshAccessibility() }
    }
}

private struct ModelSettings: View {
    let app: AppModel

    var body: some View {
        Form {
            Section("Transcription") {
                ForEach(ModelCatalog.all) { model in
                    ModelRow(model: model, library: app.library, network: app.network)
                }
            }
        }
        .formStyle(.grouped)
        .task { await app.library.refresh() }
    }
}

private struct HistorySettings: View {
    let app: AppModel
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                RetentionPicker(period: Bindable(app.settings).retentionPeriod)
            } footer: {
                Text(
                    "Each result keeps the transcript, the recording and the cleaned version. A shorter period also applies to results already kept."
                )
            }
            Section {
                Button("Delete All Results…", role: .destructive) { confirmingDelete = true }
                    .disabled(app.history.entries.isEmpty)
            }
        }
        .formStyle(.grouped)
        .onChange(of: app.settings.retentionPeriod) { Task { await app.history.refresh() } }
        .task { await app.history.refresh() }
        .confirmationDialog("Delete all results?", isPresented: $confirmingDelete) {
            Button("Delete All", role: .destructive) { Task { await app.history.deleteAll() } }
        } message: {
            Text("Transcripts, recordings and cleaned versions are deleted from this Mac.")
        }
    }
}

private struct PrivacySettings: View {
    let app: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                PrivacyNotice(period: app.settings.retentionPeriod)
                Divider()
                Text("Acknowledgements").font(Tokens.heading)
                Acknowledgements()
            }
            .padding(Tokens.Spacing.xl)
        }
    }
}
