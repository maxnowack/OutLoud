import OutloudKit
import SwiftUI

/// The dictation state as icon and words (`docs/DESIGN.md` §"StatusIndicator").
public struct StatusIndicator: View {
    let state: DictationState
    let progress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    /// - Parameter progress: How far the cleanup is, 0 to 1, shown as a bar while cleaning.
    public init(state: DictationState, progress: Double? = nil) {
        self.state = state
        self.progress = progress
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.s) {
            icon
                .frame(width: 20, height: 20)
            Text(Self.label(for: state))
                .font(Tokens.heading)
                .foregroundStyle(Tokens.textPrimary)
            if state == .cleaning, let progress {
                ProgressView(value: progress)
                    .frame(width: Tokens.progressBarWidth)
                    .tint(Tokens.accent)
                    .animation(Tokens.standard, value: progress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(for: state))
        .accessibilityValue(
            state == .cleaning && progress != nil
                ? (progress ?? 0).formatted(.percent.precision(.fractionLength(0))) : ""
        )
        .onChange(of: state) { _, new in announce(Self.label(for: new)) }
    }

    @ViewBuilder private var icon: some View {
        switch state {
        case .idle:
            Image(systemName: "waveform").foregroundStyle(Tokens.accent)
        case .recording:
            Image(systemName: "record.circle.fill")
                .foregroundStyle(Tokens.recording)
                .scaleEffect(pulsing && !reduceMotion ? 1.15 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Tokens.pulse) { pulsing = true }
                }
                .onDisappear { pulsing = false }
        case .transcribing, .cleaning:
            ProgressView().controlSize(.small)
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.success)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Tokens.failure)
        }
    }

    public static func label(for state: DictationState) -> String {
        switch state {
        case .idle: localized("Ready")
        case .recording: localized("Recording…")
        case .transcribing: localized("Transcribing…")
        case .cleaning: localized("Cleaning up…")
        case .finished: localized("Done")
        case .failed: localized("Something went wrong")
        }
    }
}

/// The input level as five bars (`docs/DESIGN.md` §"LevelMeter").
public struct LevelMeter: View {
    let level: Float

    public init(level: Float) {
        self.level = level
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.xs / 2) {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(
                        Float(index) < level * 5
                            ? Tokens.recording : Tokens.textSecondary.opacity(0.3)
                    )
                    .frame(width: 4, height: 6 + CGFloat(index) * 3)
            }
        }
        .animation(Tokens.standard, value: level)
        .accessibilityHidden(true)
    }
}
