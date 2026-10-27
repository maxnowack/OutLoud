import OutloudKit
import SwiftUI

/// The dictation state as icon and words (`docs/DESIGN.md` §"StatusIndicator").
public struct StatusIndicator: View {
    let state: DictationState
    let progress: Double?
    let secondsLeft: Int?
    let voice: [Float]?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    /// - Parameters:
    ///   - progress: How far the transcription or the cleanup is, 0 to 1, shown as a ring
    ///     while transcribing and cleaning.
    ///   - secondsLeft: Roughly how long it still takes (`DictationController.secondsLeft`),
    ///     counted down inside the ring.
    ///   - voice: The shape of the voice (`DictationController.voice`); given, a recording shows
    ///     "Recording…" above the LevelWave.
    public init(
        state: DictationState, progress: Double? = nil, secondsLeft: Int? = nil,
        voice: [Float]? = nil
    ) {
        self.state = state
        self.progress = progress
        self.secondsLeft = secondsLeft
        self.voice = voice
    }

    public var body: some View {
        Group {
            if state == .recording, let voice {
                VStack(spacing: Tokens.Spacing.xs) {
                    label
                    LevelWave(voice: voice)
                }
            } else {
                HStack(spacing: Tokens.Spacing.s) {
                    let iconSize =
                        ringProgress == nil ? Tokens.statusIconSize : Tokens.progressRingSize
                    icon
                        .frame(width: iconSize, height: iconSize)
                    label
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(for: state))
        .accessibilityValue(accessibilityValue)
        .onChange(of: state) { _, new in announce(Self.label(for: new)) }
    }

    private var label: some View {
        Text(Self.label(for: state))
            .font(Tokens.heading)
            .foregroundStyle(Tokens.textPrimary)
    }

    /// The seconds left while they are counted down, else how far the step is.
    private var accessibilityValue: String {
        guard let ringProgress else { return "" }
        if let ringSecondsLeft { return localized("About \(ringSecondsLeft) seconds left") }
        return ringProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    /// The seconds left inside the ring: up to two digits, which it holds.
    private var ringSecondsLeft: Int? {
        guard ringProgress != nil, let secondsLeft, secondsLeft < 100 else { return nil }
        return secondsLeft
    }

    /// The progress to show as a ring, while transcribing or cleaning.
    private var ringProgress: Double? {
        state == .transcribing || state == .cleaning ? progress : nil
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
            if let ringProgress {
                ProgressRing(value: ringProgress, secondsLeft: ringSecondsLeft)
                    // A new ring for the cleanup, rather than the transcription's running back.
                    .id(state == .cleaning)
            } else {
                ProgressView().controlSize(.small)
            }
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

/// How far a step is, as a ring that fills clockwise in `accent` (`docs/DESIGN.md`
/// §"StatusIndicator"). Drawn rather than the system's circular ProgressView, which shows no
/// value on iOS.
private struct ProgressRing: View {
    let value: Double
    let secondsLeft: Int?

    var body: some View {
        ZStack {
            Circle().stroke(Tokens.textSecondary.opacity(0.3), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: value)
                .stroke(Tokens.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let secondsLeft {
                Text(secondsLeft, format: .number)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(Tokens.standard, value: secondsLeft)
            }
        }
        .padding(2)
        .animation(Tokens.standard, value: value)
    }
}

/// The voice at the microphone as a line in `recording`: the shape of its last few hundredths of
/// a second, as large as it is loud, so that it lies flat in silence and changes with every sound
/// (`docs/DESIGN.md` §"LevelWave"). With Reduce Motion it shows a calm sine instead, which only
/// grows and shrinks with the level.
public struct LevelWave: View {
    let voice: [Float]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter voice: Points from -1 to 1, scaled by the level (`DictationController.voice`).
    public init(voice: [Float]) {
        self.voice = voice
    }

    public var body: some View {
        VoiceLine(points: reduceMotion ? Self.calm(as: voice) : voice)
            .stroke(
                Tokens.recording,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: Tokens.levelWaveSize.width, height: Tokens.levelWaveSize.height)
            .accessibilityHidden(true)
    }

    /// Three periods of a sine, as high as the voice's peak.
    static func calm(as voice: [Float]) -> [Float] {
        let level = voice.map(abs).max() ?? 0
        return (0..<48).map { level * Float(sin(Double($0) / 47 * 6 * .pi)) }
    }
}

/// A smooth line through `points` from -1 to 1 across the width, tapered to the ends so that it
/// starts and ends on the middle line; 1 reaches the edges.
private struct VoiceLine: Shape {
    let points: [Float]

    func path(in rect: CGRect) -> Path {
        Path { path in
            let start = CGPoint(x: rect.minX, y: rect.midY)
            path.move(to: start)
            guard points.count > 1 else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                return
            }
            let last = Double(points.count - 1)
            let positions = points.enumerated().map { index, value in
                let x = Double(index) / last
                return CGPoint(
                    x: rect.minX + x * rect.width,
                    y: rect.midY - Double(value) * (rect.height / 2 - 1) * sin(.pi * x))
            }
            // Through the midpoints, with the points as control points: a smooth curve, not a
            // line of corners.
            for (point, next) in zip(positions, positions.dropFirst()) {
                path.addQuadCurve(
                    to: CGPoint(x: (point.x + next.x) / 2, y: (point.y + next.y) / 2),
                    control: point)
            }
            path.addLine(to: positions[positions.count - 1])
        }
    }
}
