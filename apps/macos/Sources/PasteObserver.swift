import Foundation
import OutloudKit

/// Watches the field a result was pasted into for the user's correction of it (ADR 0040): it
/// reads the field once a second for up to 15 s, while that field keeps the focus, and once the
/// text has not changed for 2 s, hands the pair the edit teaches to `learn`.
///
/// Polled, as `AppModel.pollFocus` is: Accessibility sends no value change for many fields, and
/// an Electron app's field does not say when it shows other content. The text is held in memory
/// only, for the comparison, and never logged.
@MainActor
final class PasteObserver {
    static let window = Duration.seconds(15)
    static let interval = Duration.seconds(1)
    static let quiet = Duration.seconds(2)
    /// Lets the target handle the ⌘V before its text counts as the pasted one; it reads the
    /// clipboard asynchronously (`AutoPaster.deliver`).
    static let settle = Duration.milliseconds(700)

    private var watching: Task<Void, Never>?

    /// Starts watching, and stops watching an earlier paste.
    func watch(
        _ pasted: String, in target: AutoPaster.Target,
        learn: @escaping @MainActor (_ heard: String, _ meant: String) -> Void
    ) {
        stop()
        watching = Task {
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled, let before = AutoPaster.text(of: target) else { return }
            let clock = ContinuousClock()
            let end = clock.now + Self.window
            var last = before
            var changedAt = clock.now
            while clock.now < end {
                try? await Task.sleep(for: Self.interval)
                // The user left the field, or another dictation began.
                guard !Task.isCancelled, let current = AutoPaster.text(of: target) else { return }
                if current != last {
                    last = current
                    changedAt = clock.now
                } else if current != before, clock.now - changedAt >= Self.quiet {
                    break
                }
            }
            guard last != before, clock.now - changedAt >= Self.quiet,
                let pair = CorrectionLearning.pair(pasted: pasted, before: before, after: last)
            else { return }
            learn(pair.heard, pair.meant)
        }
    }

    func stop() {
        watching?.cancel()
        watching = nil
    }
}
