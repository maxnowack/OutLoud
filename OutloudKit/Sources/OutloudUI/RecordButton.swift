import SwiftUI

/// Starts and ends a recording on iOS (`docs/DESIGN.md` §"RecordButton").
public struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    public init(isRecording: Bool, action: @escaping () -> Void) {
        self.isRecording = isRecording
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Tokens.recording : Tokens.accentFill)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: Tokens.recordButtonSize * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: Tokens.recordButtonSize, height: Tokens.recordButtonSize)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Tokens.standard, value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isRecording ? localized("Stop dictation") : localized("Start dictation")
        )
        .accessibilityAddTraits(.isButton)
    }
}
