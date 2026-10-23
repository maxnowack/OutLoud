import OutloudKit
import OutloudUI
import SwiftUI

/// The dictate tab (`docs/DESIGN.md` §"Screens": iOS dictate tab).
struct DictateScreen: View {
    let app: AppModel
    @State private var typed = ""
    @FocusState private var editing: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Spacing.xl) {
                    VStack(spacing: Tokens.Spacing.l) {
                        StatusIndicator(state: app.isRecording ? .recording : app.dictation.state)
                        if app.isRecording {
                            LevelMeter(level: app.dictation.level)
                        }
                        RecordButton(isRecording: app.isRecording) {
                            Task { await app.toggleRecording() }
                        }
                        .disabled(!app.dictation.hasRequiredModels || isProcessing)
                        Text(
                            app.isRecording
                                ? "Tap to stop. The text is copied to the clipboard."
                                : "Tap to dictate. Paste the text in any app afterwards."
                        )
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, Tokens.Spacing.xl)

                    if case .failed(let failure) = app.dictation.state {
                        FailureNotice(failure: failure) { failure in
                            if failure == .microphoneDenied,
                                let url = URL(string: UIApplication.openSettingsURLString)
                            {
                                openURL(url)
                            }
                        }
                    }

                    if let outcome = app.lastOutcome {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                            Label("Copied to the clipboard", systemImage: "doc.on.clipboard")
                                .font(Tokens.caption)
                                .foregroundStyle(Tokens.success)
                            ResultCard(outcome: outcome)
                        }
                    }

                    systemDictation
                }
                .padding(Tokens.Spacing.l)
            }
            .navigationTitle("Outloud")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var isProcessing: Bool {
        app.dictation.state == .transcribing || app.dictation.state == .cleaning
    }

    /// Text from the keyboard's dictation, cleaned up on request (ADR 0003).
    private var systemDictation: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            Text("Or use the keyboard's dictation").font(Tokens.heading)
            TextEditor(text: $typed)
                .focused($editing)
                .frame(minHeight: 100)
                .padding(Tokens.Spacing.s)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusMedium))
                .accessibilityLabel("Text to clean up")
            HStack {
                Button("Clear") { typed = "" }
                    .disabled(typed.isEmpty)
                Spacer()
                Button(app.settings.cleanupEnabled ? "Clean Up and Copy" : "Copy") {
                    editing = false
                    Task {
                        if await app.cleanUp(text: typed) != nil { typed = "" }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
        }
    }
}
