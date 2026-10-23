@preconcurrency import AVFoundation
import Foundation
import Observation

/// The history for the interface: the entries, their removal when the period ends, and playing
/// an entry's audio (`docs/SPEC.md` §"History").
@MainActor
@Observable
public final class HistoryModel {
    public private(set) var entries: [HistoryEntry] = []
    /// The entry whose audio is playing.
    public private(set) var playing: HistoryEntry.ID?

    public let store: HistoryStore
    @ObservationIgnored private let settings: OutloudSettings
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playerDelegate: PlayerDelegate?
    @ObservationIgnored private var expiryTimer: Task<Void, Never>?

    public init(store: HistoryStore, settings: OutloudSettings) {
        self.store = store
        self.settings = settings
    }

    /// Removes what has expired and reloads the entries.
    public func refresh() async {
        try? await store.removeExpired(
            now: Date(), period: settings.retentionPeriod, calendar: .current)
        entries = await store.all()
    }

    /// Removes expired entries every few minutes while the app runs, so that a result does not
    /// outlive its period because the app stayed open.
    public func startExpiringEntries() {
        expiryTimer?.cancel()
        expiryTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    public func delete(_ entry: HistoryEntry) async {
        if playing == entry.id { stop() }
        try? await store.delete(entry.id)
        entries = await store.all()
    }

    public func deleteAll() async {
        stop()
        try? await store.deleteAll()
        entries = []
    }

    public func play(_ entry: HistoryEntry) async {
        stop()
        guard entry.hasAudio else { return }
        let url = await store.audioURL(of: entry)
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        let delegate = PlayerDelegate { [weak self] in
            Task { @MainActor [weak self] in self?.playing = nil }
        }
        player.delegate = delegate
        self.player = player
        playerDelegate = delegate
        if player.play() { playing = entry.id }
    }

    public func stop() {
        player?.stop()
        player = nil
        playerDelegate = nil
        playing = nil
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    private let finished: @Sendable () -> Void

    init(finished: @escaping @Sendable () -> Void) {
        self.finished = finished
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finished()
    }
}
