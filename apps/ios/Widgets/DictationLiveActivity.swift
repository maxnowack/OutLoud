import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A dictation started without the app in front, in the Dynamic Island and on the Lock Screen:
/// what is happening now, from the recording to the copied text.
struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationActivityAttributes.self) { context in
            HStack(spacing: 12) {
                PhaseIcon(state: context.state).font(.title2)
                PhaseText(state: context.state)
                Spacer(minLength: 0)
                StopButton(state: context.state)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseIcon(state: context.state).font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    PhaseText(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StopButton(state: context.state)
                }
            } compactLeading: {
                PhaseIcon(state: context.state)
            } compactTrailing: {
                CompactDetail(state: context.state)
            } minimal: {
                PhaseIcon(state: context.state)
            }
        }
    }
}

private typealias State = DictationActivityAttributes.ContentState

private struct PhaseIcon: View {
    let state: State

    var body: some View {
        switch state.phase {
        case .recording: Image(systemName: "record.circle").foregroundStyle(.red)
        case .transcribing: Image(systemName: "waveform").foregroundStyle(.teal)
        case .cleaning: Image(systemName: "sparkles").foregroundStyle(.teal)
        case .copied: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .saved: Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(.orange)
        case .nothingRecognised, .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

private struct PhaseText: View {
    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            switch state.phase {
            case .recording:
                Text(state.since, style: .timer).monospacedDigit().foregroundStyle(.secondary)
            case .transcribing, .cleaning:
                HStack(spacing: 8) {
                    ProgressView(value: state.progress ?? 0).tint(.teal)
                    if let secondsLeft = state.secondsLeft {
                        Text(Duration.seconds(secondsLeft), format: .units(width: .narrow))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            case .copied, .saved, .nothingRecognised, .failed:
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private var title: LocalizedStringKey {
        switch state.phase {
        case .recording: "Recording"
        case .transcribing: "Transcribing…"
        case .cleaning: "Cleaning up…"
        case .copied: "Copied"
        case .saved: "Saved in Outloud"
        case .nothingRecognised: "Nothing recognised"
        case .failed: "Dictation failed"
        }
    }

    private var detail: LocalizedStringKey? {
        switch state.phase {
        case .copied: "Paste it anywhere."
        case .saved: "Not copied: run the shortcut again to end a dictation."
        case .nothingRecognised: "Try speaking a little longer."
        case .failed: "Open Outloud to see what happened."
        case .recording, .transcribing, .cleaning: nil
        }
    }
}

private struct CompactDetail: View {
    let state: State

    var body: some View {
        switch state.phase {
        case .recording:
            Text(state.since, style: .timer).monospacedDigit().frame(maxWidth: 44)
        case .transcribing, .cleaning:
            ProgressView(value: state.progress ?? 0).progressViewStyle(.circular).tint(.teal)
                .overlay {
                    // Inside the ring, as in the app (`docs/DESIGN.md` §"StatusIndicator").
                    if let secondsLeft = state.secondsLeft, secondsLeft < 100 {
                        Text(secondsLeft, format: .number)
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    }
                }
        case .copied, .saved, .nothingRecognised, .failed:
            EmptyView()
        }
    }
}

private struct StopButton: View {
    let state: State

    var body: some View {
        if state.phase == .recording {
            Button(intent: StopDictationIntent()) {
                Image(systemName: "stop.fill")
            }
            .tint(.red)
            .accessibilityLabel("Stop dictation")
        }
    }
}
