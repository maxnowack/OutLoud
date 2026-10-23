@preconcurrency import AVFoundation
import Foundation
import Observation

/// The history for the interface: the entries, their removal when the period ends, and playing
/// an entry's audio with its waveform (`docs/SPEC.md` §"History").
@MainActor
@Observable
public final class HistoryModel {
    public private(set) var entries: [HistoryEntry] = []
    /// The entry whose audio is loaded in the player, playing or paused.
    public private(set) var current: HistoryEntry.ID?
    public private(set) var isPlaying = false
    /// The position in the current entry's audio, in seconds.
    public private(set) var position: TimeInterval = 0
    /// The length of the current entry's audio, in seconds.
    public private(set) var duration: TimeInterval = 0
    /// Per entry, the loudness of its audio in equal slices, 0 to 1, for the waveform.
    public private(set) var waveforms: [HistoryEntry.ID: [Float]] = [:]

    public let store: HistoryStore
    @ObservationIgnored private let settings: OutloudSettings
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playerDelegate: PlayerDelegate?
    @ObservationIgnored private var expiryTimer: Task<Void, Never>?
    @ObservationIgnored private var positionTimer: Task<Void, Never>?

    /// The number of bars a waveform has.
    public static let waveformSlices = 48

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
        if current == entry.id { stop() }
        try? await store.delete(entry.id)
        waveforms[entry.id] = nil
        entries = await store.all()
    }

    public func deleteAll() async {
        stop()
        try? await store.deleteAll()
        waveforms = [:]
        entries = []
    }

    /// Reads an entry's audio once and keeps its waveform.
    public func loadWaveform(of entry: HistoryEntry) async {
        guard entry.hasAudio, waveforms[entry.id] == nil else { return }
        let url = await store.audioURL(of: entry)
        let slices = Self.waveformSlices
        let levels = await Task.detached {
            guard let samples = try? WAVFile.read(url).samples else { return [Float]() }
            return Waveform.levels(of: samples, slices: slices)
        }.value
        waveforms[entry.id] = levels
    }

    /// Plays an entry from where it was paused, or from the start; pauses it while it plays.
    public func togglePlayback(of entry: HistoryEntry) async {
        if current == entry.id, let player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
            } else {
                resume()
            }
            return
        }
        stop()
        guard entry.hasAudio else { return }
        let url = await store.audioURL(of: entry)
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        let delegate = PlayerDelegate { [weak self] in
            Task { @MainActor [weak self] in self?.finished() }
        }
        player.delegate = delegate
        self.player = player
        playerDelegate = delegate
        current = entry.id
        duration = player.duration
        position = 0
        resume()
    }

    /// Moves the current entry's playback to a share of its length, 0 to 1.
    public func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(1, fraction)) * player.duration
        position = player.currentTime
    }

    public func stop() {
        player?.stop()
        player = nil
        playerDelegate = nil
        positionTimer?.cancel()
        current = nil
        isPlaying = false
        position = 0
        duration = 0
    }

    private func resume() {
        guard let player, player.play() else { return }
        isPlaying = true
        positionTimer?.cancel()
        positionTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                self.position = player.currentTime
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func finished() {
        positionTimer?.cancel()
        isPlaying = false
        position = 0
        player?.currentTime = 0
    }
}

/// Loudness per slice of a recording, for drawing its waveform.
public enum Waveform {
    /// The root mean square of each of `slices` equal parts, scaled so the loudest is 1.
    public static func levels(of samples: [Float], slices: Int) -> [Float] {
        guard !samples.isEmpty, slices > 0 else { return [] }
        let size = max(1, samples.count / slices)
        var levels: [Float] = []
        levels.reserveCapacity(slices)
        for slice in 0..<slices {
            let start = slice * size
            guard start < samples.count else {
                levels.append(0)
                continue
            }
            let end = min(samples.count, start + size)
            var sum: Float = 0
            for index in start..<end { sum += samples[index] * samples[index] }
            levels.append((sum / Float(end - start)).squareRoot())
        }
        let loudest = levels.max() ?? 0
        return loudest > 0 ? levels.map { $0 / loudest } : levels
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
