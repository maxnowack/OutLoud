import SwiftUI

/// Steps through the kept results, above the ResultCard (`docs/DESIGN.md` §"ResultPager").
public struct ResultPager: View {
    /// The result shown, from 1 for the newest.
    let position: Int
    let count: Int
    let date: Date
    let older: () -> Void
    let newer: () -> Void

    public init(
        position: Int, count: Int, date: Date, older: @escaping () -> Void,
        newer: @escaping () -> Void
    ) {
        self.position = position
        self.count = count
        self.date = date
        self.older = older
        self.newer = newer
    }

    public var body: some View {
        // Newer to the left, older to the right, as the user asked on 2026-10-30.
        HStack(spacing: Tokens.Spacing.s) {
            Button(action: newer) { Image(systemName: "chevron.left") }
                .disabled(position <= 1)
                .accessibilityLabel(localized("Newer result"))
                .help(localized("Newer result (←)"))
            Spacer()
            Text(
                localized(
                    "\(position) of \(count) · \(date.formatted(.dateTime.day().month().hour().minute()))"
                )
            )
            .font(Tokens.caption)
            .foregroundStyle(Tokens.textSecondary)
            Spacer()
            Button(action: older) { Image(systemName: "chevron.right") }
                .disabled(position >= count)
                .accessibilityLabel(localized("Older result"))
                .help(localized("Older result (→)"))
        }
        .controlSize(.small)
    }
}
