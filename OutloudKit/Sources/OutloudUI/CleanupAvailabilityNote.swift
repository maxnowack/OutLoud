import OutloudKit
import SwiftUI

/// Whether the cleanup can run, and what to do when it cannot (`docs/DESIGN.md`
/// §"CleanupAvailabilityNote"; ADR 0019).
public struct CleanupAvailabilityNote: View {
    let availability: CleanupAvailability

    public init(availability: CleanupAvailability) {
        self.availability = availability
    }

    public var body: some View {
        Label(text, systemImage: isAvailable ? "apple.intelligence" : "exclamationmark.circle")
            .font(Tokens.caption)
            .foregroundStyle(isAvailable ? Tokens.textSecondary : Tokens.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var isAvailable: Bool { availability == .available }

    private var text: String {
        switch availability {
        case .available:
            localized("Uses Apple Intelligence on this device. No download.")
        case .deviceNotEligible:
            localized("This device does not support Apple Intelligence; you get the transcript.")
        case .appleIntelligenceOff:
            localized("Switch on Apple Intelligence in the system settings to clean up text.")
        case .modelNotReady:
            localized("Apple Intelligence is still getting ready; cleanup starts once it is.")
        }
    }
}

extension View {
    /// Keeps `availability` current: read when the view appears and whenever the app comes back to
    /// the front, since the user switches Apple Intelligence on or off in the system settings.
    public func trackingCleanupAvailability(
        _ availability: Binding<CleanupAvailability>
    ) -> some View {
        modifier(CleanupAvailabilityTracking(availability: availability))
    }
}

private struct CleanupAvailabilityTracking: ViewModifier {
    @Binding var availability: CleanupAvailability
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onAppear { availability = .current }
            .onChange(of: phase) { _, phase in
                if phase == .active { availability = .current }
            }
            #if os(macOS)
                // A menu bar app's windows do not change their phase when the app comes back.
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.didBecomeActiveNotification)
                ) { _ in availability = .current }
            #endif
    }
}
