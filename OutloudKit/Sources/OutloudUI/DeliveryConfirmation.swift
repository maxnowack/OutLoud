import OutloudKit
import SwiftUI

/// The result as a confirmation that it is on the clipboard; the text itself only on request
/// (`docs/DESIGN.md` §"DeliveryConfirmation").
public struct DeliveryConfirmation: View {
    let outcome: DictationOutcome
    @State private var showingText = false

    public init(outcome: DictationOutcome) {
        self.outcome = outcome
    }

    public var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Tokens.confirmationIconSize))
                .foregroundStyle(Tokens.success)
                .accessibilityHidden(true)
            Text(localized("Copied")).font(Tokens.title)
            Text(localized("Paste the text in any app: touch and hold, then Paste."))
                .font(Tokens.body)
                .foregroundStyle(Tokens.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            CleanupNotice(outcome: outcome)
            if showingText {
                ResultCard(outcome: outcome)
                    .transition(.opacity)
            } else {
                Button(localized("Show text")) {
                    withAnimation(Tokens.standard) { showingText = true }
                }
                .buttonStyle(.bordered)
                .tint(Tokens.accent)
            }
        }
        .onChange(of: outcome) { showingText = false }
        .onAppear { announce(localized("Copied")) }
    }
}
