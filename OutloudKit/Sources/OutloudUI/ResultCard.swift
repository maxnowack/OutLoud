import OutloudKit
import SwiftUI

/// The result of a dictation with its copy button (`docs/DESIGN.md` §"ResultCard").
public struct ResultCard: View {
    let outcome: DictationOutcome
    @State private var copied = false

    public init(outcome: DictationOutcome) {
        self.outcome = outcome
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            Text(outcome.result)
                .font(Tokens.body)
                .foregroundStyle(Tokens.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if outcome.cleanupFailed {
                Label(
                    localized("Cleanup failed — this is the transcript."),
                    systemImage: "exclamationmark.circle"
                )
                .font(Tokens.caption)
                .foregroundStyle(Tokens.warning)
            }
            HStack {
                Spacer()
                Button {
                    Clipboard.copy(outcome.result)
                    copied = true
                    announce(localized("Copied"))
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(
                        copied ? localized("Copied") : localized("Copy"),
                        systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .tint(copied ? Tokens.success : Tokens.accent)
            }
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusMedium))
    }
}

/// A failure with its recovery (`docs/DESIGN.md` §"FailureNotice").
public struct FailureNotice: View {
    let failure: DictationFailure
    let recover: ((DictationFailure) -> Void)?

    public init(failure: DictationFailure, recover: ((DictationFailure) -> Void)? = nil) {
        self.failure = failure
        self.recover = recover
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            Label(Self.message(for: failure), systemImage: "exclamationmark.triangle.fill")
                .font(Tokens.detail)
                .foregroundStyle(Tokens.failure)
                .fixedSize(horizontal: false, vertical: true)
            if let recover, let action = Self.action(for: failure) {
                Button(action) { recover(failure) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    public static func message(for failure: DictationFailure) -> String {
        switch failure {
        case .microphoneDenied:
            localized("Outloud may not use the microphone. Allow it in System Settings.")
        case .modelsMissing:
            localized("The models are not downloaded yet.")
        case .nothingRecognised:
            localized("Nothing was recognised. Speak a little longer or closer to the microphone.")
        case .recordingFailed(let reason):
            localized("The recording failed: \(reason)")
        case .transcriptionFailed(let reason):
            localized("The transcription failed: \(reason)")
        }
    }

    static func action(for failure: DictationFailure) -> String? {
        switch failure {
        case .microphoneDenied: localized("Open Settings")
        case .modelsMissing: localized("Download models")
        default: nil
        }
    }
}
