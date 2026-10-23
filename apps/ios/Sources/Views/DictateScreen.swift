import OutloudKit
import OutloudUI
import SwiftUI

/// The dictate tab (`docs/DESIGN.md` §"Screens": iOS dictate tab): the state in the middle,
/// the record button within the thumb's reach at the bottom.
struct DictateScreen: View {
    let app: AppModel
    @AppStorage("shortcutHintDismissed") private var hintDismissed = false
    @State private var showingGuide = false
    @State private var showingTextEntry = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.l) {
                if !hintDismissed {
                    ShortcutHintCard(
                        open: { showingGuide = true }, dismiss: { hintDismissed = true })
                }
                Spacer(minLength: 0)
                state
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                VStack(spacing: Tokens.Spacing.s) {
                    RecordButton(isRecording: app.isRecording) {
                        Task { await app.toggleRecording() }
                    }
                    .disabled(!app.dictation.hasRequiredModels || isProcessing)
                    Button("Type text instead") { showingTextEntry = true }
                        .disabled(app.isRecording || isProcessing)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.bottom, Tokens.Spacing.xl)
            .navigationTitle("Outloud")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGuide = true
                    } label: {
                        Image(systemName: "bolt")
                    }
                    .accessibilityLabel("Ways to start Outloud")
                }
            }
            .sheet(isPresented: $showingGuide) { ShortcutGuide() }
            .sheet(isPresented: $showingTextEntry) { TextEntrySheet(app: app) }
        }
    }

    private var isProcessing: Bool {
        app.dictation.state == .transcribing || app.dictation.state == .cleaning
    }

    @ViewBuilder private var state: some View {
        if app.isRecording {
            VStack(spacing: Tokens.Spacing.m) {
                StatusIndicator(state: .recording)
                LevelMeter(level: app.dictation.level)
                hint("Tap to stop. The text is copied to the clipboard.")
            }
        } else {
            switch app.dictation.state {
            case .transcribing, .cleaning:
                StatusIndicator(state: app.dictation.state)
            case .finished(let outcome):
                DeliveryConfirmation(outcome: outcome)
            case .failed(let failure):
                FailureNotice(failure: failure) { failure in
                    if failure == .microphoneDenied,
                        let url = URL(string: UIApplication.openSettingsURLString)
                    {
                        openURL(url)
                    }
                }
            case .idle, .recording:
                VStack(spacing: Tokens.Spacing.s) {
                    StatusIndicator(state: .idle)
                    hint("Tap, speak, tap again.\nThe text lands on the clipboard.")
                }
            }
        }
    }

    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Tokens.body)
            .foregroundStyle(Tokens.textSecondary)
            .multilineTextAlignment(.center)
    }
}

/// Points to the ways of starting Outloud without opening it, until dismissed.
private struct ShortcutHintCard: View {
    let open: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Button(action: open) {
                HStack(spacing: Tokens.Spacing.m) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Tokens.accent, in: RoundedRectangle(cornerRadius: Tokens.radiusMedium))
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs / 2) {
                        Text("Dictate with the Action Button").font(Tokens.heading)
                        Text("Or from the Control Center, the Lock Screen, Siri …")
                            .font(Tokens.caption)
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(Tokens.caption.weight(.semibold))
                    .foregroundStyle(Tokens.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide")
        }
        .padding(.leading, Tokens.Spacing.m)
        .background(
            Tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Tokens.radiusLarge))
    }
}

/// Text from the keyboard's dictation, cleaned up and copied (ADR 0003).
private struct TextEntrySheet: View {
    let app: AppModel
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .padding(Tokens.Spacing.s)
                .accessibilityLabel("Text to clean up")
                .navigationTitle("Type or dictate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(app.settings.cleanupEnabled ? "Clean Up and Copy" : "Copy") {
                            Task {
                                if await app.cleanUp(text: text) != nil { dismiss() }
                            }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { focused = true }
        }
    }
}
