import OutloudKit
import SwiftUI

/// A kept recording with a large play button, its waveform and the time
/// (`docs/DESIGN.md` §"AudioPlayer").
public struct AudioPlayer: View {
    let entry: HistoryEntry
    let history: HistoryModel

    public init(entry: HistoryEntry, history: HistoryModel) {
        self.entry = entry
        self.history = history
    }

    private var isCurrent: Bool { history.current == entry.id }
    private var isPlaying: Bool { isCurrent && history.isPlaying }
    private var progress: Double {
        guard isCurrent, history.duration > 0 else { return 0 }
        return history.position / history.duration
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Button {
                Task { await history.togglePlayback(of: entry) }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: Tokens.playButtonSize * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: Tokens.playButtonSize, height: Tokens.playButtonSize)
                    .background(Tokens.accentFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? localized("Pause") : localized("Play"))

            VStack(spacing: Tokens.Spacing.xs) {
                WaveformView(levels: history.waveforms[entry.id] ?? [], progress: progress) {
                    fraction in
                    if isCurrent { history.seek(to: fraction) }
                }
                .frame(height: Tokens.waveformHeight)
                HStack {
                    Text(Self.time(isCurrent ? history.position : 0))
                    Spacer()
                    if isCurrent { Text(Self.time(history.duration)) }
                }
                .font(Tokens.caption.monospacedDigit())
                .foregroundStyle(Tokens.textSecondary)
            }
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusLarge))
        .task { await history.loadWaveform(of: entry) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localized("Recording"))
    }

    static func time(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Bars for the loudness of a recording; the played part is drawn in the accent colour.
struct WaveformView: View {
    let levels: [Float]
    let progress: Double
    let seek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !levels.isEmpty else { return }
                let step = size.width / CGFloat(levels.count)
                let barWidth = max(2, step * 0.55)
                for (index, level) in levels.enumerated() {
                    let height = max(3, CGFloat(level) * size.height)
                    let rect = CGRect(
                        x: CGFloat(index) * step + (step - barWidth) / 2,
                        y: (size.height - height) / 2, width: barWidth, height: height)
                    let played = (CGFloat(index) + 0.5) / CGFloat(levels.count) <= progress
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(played ? Tokens.accent : Tokens.textSecondary.opacity(0.35)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    seek(value.location.x / max(geometry.size.width, 1))
                })
        }
        .accessibilityHidden(true)
    }
}
