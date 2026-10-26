import OutloudKit
import OutloudUI
import SwiftUI

/// The first launch (`docs/DESIGN.md` §"Screens": iOS setup).
struct SetupScreen: View {
    let app: AppModel

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ModelSetup(library: app.library, settings: app.settings, network: app.network) {
                    Task { await app.dictation.preloadModels() }
                }
                .padding(Tokens.Spacing.l)
                .frame(minHeight: geometry.size.height)
            }
        }
        .task { await app.library.refresh() }
    }
}

/// The history tab (`docs/DESIGN.md` §"Screens": iOS history tab).
struct HistoryScreen: View {
    let app: AppModel
    @State private var selection: HistoryEntry.ID?

    var body: some View {
        NavigationStack {
            HistoryList(
                history: app.history, period: app.settings.retentionPeriod, selection: $selection
            )
            .navigationTitle("History")
            .navigationDestination(item: $selection) { id in
                if let entry = app.history.entries.first(where: { $0.id == id }) {
                    HistoryEntryDetail(entry: entry, history: app.history)
                        .navigationTitle(
                            entry.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .task { await app.history.refresh() }
    }
}

/// The settings tab (`docs/DESIGN.md` §"Screens": iOS settings tab).
struct SettingsScreen: View {
    let app: AppModel
    @State private var confirmingDelete = false
    @State private var showingGuide = false

    @State private var cleanup = CleanupAvailability.current

    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle(
                        "Pause playback while dictating",
                        isOn: Bindable(app.settings).pausesPlayback)
                } footer: {
                    Text(
                        "Music and podcasts pause while you dictate in Outloud and may play on afterwards. From the shortcut, iOS only lets Outloud turn music down and pause spoken audio."
                    )
                }

                Section("Transcription model") {
                    ForEach(ModelCatalog.all) { model in
                        ModelRow(model: model, library: app.library, network: app.network)
                    }
                }

                Section {
                    RetentionPicker(period: Bindable(app.settings).retentionPeriod)
                    Button("Delete All Results", role: .destructive) { confirmingDelete = true }
                        .disabled(app.history.entries.isEmpty)
                } header: {
                    Text("History")
                } footer: {
                    Text(
                        "Each result keeps the transcript, the recording and the cleaned version. A shorter period also applies to results already kept."
                    )
                }

                Section {
                    Button("Dictate from any app") { showingGuide = true }
                    NavigationLink("Privacy") {
                        ScrollView {
                            PrivacyNotice(period: app.settings.retentionPeriod).padding(
                                Tokens.Spacing.l)
                        }
                        .navigationTitle("Privacy")
                    }
                    NavigationLink("Acknowledgements") {
                        ScrollView { Acknowledgements().padding(Tokens.Spacing.l) }
                            .navigationTitle("Acknowledgements")
                    }
                }
            }
            .navigationTitle("Settings")
            .trackingCleanupAvailability($cleanup)
            .onChange(of: app.settings.retentionPeriod) { Task { await app.history.refresh() } }
            .confirmationDialog(
                "Delete all results?", isPresented: $confirmingDelete, titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) { Task { await app.history.deleteAll() } }
            } message: {
                Text("Transcripts, recordings and cleaned versions are deleted from this iPhone.")
            }
            .task { await app.library.refresh() }
            .sheet(isPresented: $showingGuide) { ShortcutGuide() }
        }
    }
}
