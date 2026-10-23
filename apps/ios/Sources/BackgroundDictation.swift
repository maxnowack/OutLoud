import ActivityKit
import OutloudKit
import OutloudUI
import UIKit

/// A dictation from another app (ADR 0022): "Start or Stop Dictation with Outloud" records while
/// the user stays in their app, and returns the cleaned text for the shortcut to copy. iOS lets
/// the app open the microphone from the background only with an audio session that mixes with
/// other audio, and only while a Live Activity shows the recording; the activity goes on to show
/// the processing and how the dictation ended.
@MainActor
final class BackgroundDictation {
    static let shared = BackgroundDictation(app: .shared)

    private let app: AppModel
    private var activityID: String?
    private var recordingSince = Date.now

    init(app: AppModel) {
        self.app = app
    }

    /// Whether a dictation started here is recording.
    var isRunning: Bool { activityID != nil && app.dictation.state == .recording }

    /// Starts a recording, or ends it and returns the text.
    func toggle() async -> String? {
        if app.dictation.state == .recording { return await stop() }
        await app.start()
        // A second run while the last dictation is still processed starts nothing.
        guard app.dictation.hasRequiredModels, !app.dictation.state.isBusy else { return nil }
        recordingSince = .now
        activityID = try? Activity.request(
            attributes: DictationActivityAttributes(),
            content: .init(state: .init(phase: .recording, since: recordingSince), staleDate: nil)
        ).id
        if await !app.dictation.startRecording(mixable: true) {
            app.dictation.reset()
            await finish(.failed)
        }
        return nil
    }

    /// Ends the recording, transcribes and cleans it up, and returns the text.
    ///
    /// - Parameter viaShortcut: The shortcut copies what this returns. Ended otherwise — the Live
    ///   Activity's button, the record button —, the text is copied only when Outloud is in front.
    func stop(viaShortcut: Bool = true) async -> String? {
        guard app.dictation.state == .recording else { return nil }
        // The processing has to finish even if iOS would suspend the app meanwhile.
        let task = UIApplication.shared.beginBackgroundTask(withName: "Dictation")
        defer { UIApplication.shared.endBackgroundTask(task) }
        await show(.init(phase: .transcribing, since: recordingSince))
        // Follows the dictation's state into the Live Activity while it is processed.
        let watcher = Task { [weak self] in
            var last: DictationActivityAttributes.ContentState?
            while !Task.isCancelled, let self {
                if let state = self.activityState(), state != last {
                    last = state
                    await self.show(state)
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        let outcome = await app.dictation.stopRecording()
        watcher.cancel()
        let nothingRecognised = app.dictation.state == .failed(.nothingRecognised)
        app.dictation.reset()
        guard let outcome else {
            await finish(nothingRecognised ? .nothingRecognised : .failed)
            return nil
        }
        if viaShortcut {
            await finish(.copied)
        } else if UIApplication.shared.applicationState == .active {
            Clipboard.copy(outcome.result)
            await finish(.copied)
        } else {
            await finish(.saved)
        }
        return outcome.result
    }

    /// The Live Activity's state for the dictation's, while it is processed; the cleanup's
    /// progress in steps of 5 %, since iOS limits how often an activity may change.
    private func activityState() -> DictationActivityAttributes.ContentState? {
        switch app.dictation.state {
        case .transcribing:
            return .init(phase: .transcribing, since: recordingSince)
        case .cleaning:
            let progress = ((app.dictation.cleanupProgress ?? 0) * 20).rounded() / 20
            return .init(phase: .cleaning, since: recordingSince, progress: progress)
        default:
            return nil
        }
    }

    private func show(_ state: DictationActivityAttributes.ContentState) async {
        guard let id = activityID else { return }
        await Self.change(id, to: state, endingAfter: nil)
    }

    /// Shows how the dictation ended for a moment, then removes the Live Activity.
    private func finish(_ phase: DictationActivityAttributes.ContentState.Phase) async {
        guard let id = activityID else { return }
        activityID = nil
        await Self.change(
            id, to: .init(phase: phase, since: recordingSince), endingAfter: .seconds(4))
    }

    /// Looks the activity up by its identifier: it cannot cross into the main actor and back.
    private nonisolated static func change(
        _ id: String, to state: DictationActivityAttributes.ContentState,
        endingAfter delay: Duration?
    ) async {
        guard
            let activity = Activity<DictationActivityAttributes>.activities.first(where: {
                $0.id == id
            })
        else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if let delay {
            await activity.end(
                content, dismissalPolicy: .after(.now + TimeInterval(delay.components.seconds)))
        } else {
            await activity.update(content)
        }
    }
}
