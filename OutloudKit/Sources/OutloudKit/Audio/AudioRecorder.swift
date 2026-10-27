@preconcurrency import AVFoundation
import Foundation
import Synchronization
import os

public enum AudioRecorderError: Error, Equatable, Sendable {
    case noInput
    case alreadyRecording
}

/// Captures the microphone as 16 kHz mono samples, the format transcription takes.
///
/// The capture is shared by both apps (ADR 0013); each app asks for the microphone permission
/// and decides when a recording starts and ends.
public final class AudioRecorder: @unchecked Sendable {
    public static let sampleRate = 16_000.0

    private var engine = AVAudioEngine()
    /// Whether the input node carries the tap; only `start` and `stopEngine` change it.
    private var tapInstalled = false
    /// Measures the input for the level, attached only while recording.
    private var meter: AVAudioSinkNode?
    /// The loudest mean square of an IO buffer since `takeLevel`, as the bits of a `Float`. The
    /// bits of non-negative floats order as their values, so `max` on them is lock-free, as the
    /// audio thread needs.
    private let loudest = Atomic<UInt32>(0)
    /// The input's last tenth of a second, for the waveform. The audio thread writes only when
    /// the lock is free, so that it never waits; a buffer missed while the waveform is read is
    /// not missed by the recording, which the tap takes.
    private let recent = OSAllocatedUnfairLock(initialState: RecentAudio())
    private let lock = NSLock()
    // Guarded by `lock`.
    private var samples: [Float] = []
    private var isRecording = false

    public init() {}

    /// What a recording does to other audio on iOS (ADR 0024); macOS has no audio session.
    public enum OtherAudio: Sendable {
        /// An exclusive session: other audio is interrupted and may resume afterwards.
        case interrupt
        /// A session that mixes, turning music down and pausing spoken audio; one that iOS allows
        /// an app in the background, where it refuses an exclusive one
        /// (`plans/BACKGROUND_DICTATION.md`, spike 2).
        case quiet
        /// A session that mixes and leaves other audio as it is.
        case mix
    }

    /// Starts recording.
    ///
    /// - Parameters:
    /// - Parameter otherAudio: iOS: what the session does to other audio.
    public func start(otherAudio: OtherAudio = .interrupt) throws {
        try lock.withLock {
            guard !isRecording else { throw AudioRecorderError.alreadyRecording }
            isRecording = true
            samples = []
        }
        do {
            #if os(iOS)
                let session = AVAudioSession.sharedInstance()
                switch otherAudio {
                case .interrupt:
                    try session.setCategory(.record, mode: .default)
                    try session.setActive(true)
                case .quiet:
                    do {
                        try session.setCategory(
                            .playAndRecord, mode: .default,
                            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
                        try session.setActive(true)
                    } catch {
                        // Turning others down is a courtesy; a session that only mixes still
                        // records.
                        try session.setCategory(
                            .playAndRecord, mode: .default, options: [.mixWithOthers])
                        try session.setActive(true)
                    }
                case .mix:
                    try session.setCategory(
                        .playAndRecord, mode: .default, options: [.mixWithOthers])
                    try session.setActive(true)
                }
            #endif
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
                let target = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1,
                    interleaved: false),
                let converter = AVAudioConverter(from: inputFormat, to: target)
            else { throw AudioRecorderError.noInput }

            (input as any TapInstalling).installTap(
                onBus: 0, bufferSize: 4096, format: inputFormat
            ) {
                [weak self] buffer, _ in
                guard let self, let converted = Self.convert(buffer, with: converter, to: target)
                else { return }
                self.lock.withLock { self.samples.append(contentsOf: converted) }
            }
            tapInstalled = true
            let meter = AVAudioSinkNode { [unowned self] _, frameCount, buffers in
                let channel = UnsafeMutableAudioBufferListPointer(
                    UnsafeMutablePointer(mutating: buffers))[0]
                guard frameCount > 0, let data = channel.mData?.assumingMemoryBound(to: Float.self)
                else { return noErr }
                var sum: Float = 0
                for index in 0..<Int(frameCount) { sum += data[index] * data[index] }
                self.loudest.max((sum / Float(frameCount)).bitPattern, ordering: .relaxed)
                self.recent.withLockIfAvailableUnchecked { recent in
                    for index in 0..<Int(frameCount) {
                        recent.samples[recent.next] = data[index]
                        recent.next = (recent.next + 1) % recent.samples.count
                    }
                }
                return noErr
            }
            engine.attach(meter)
            try engine.connectNode(input, to: meter, format: inputFormat)
            self.meter = meter
            loudest.store(0, ordering: .relaxed)
            recent.withLock {
                $0 = RecentAudio(sampleRate: inputFormat.sampleRate)
            }
            engine.prepare()
            try engine.start()
        } catch {
            stopEngine()
            // An engine whose input node was created while the session was inactive keeps a
            // format of 0 Hz, and every later start fails with `noInput`; a fresh one does not.
            engine = AVAudioEngine()
            lock.withLock { isRecording = false }
            throw error
        }
    }

    /// The level of the loudest moment since the last call, 0 to 1; the IO buffers it is
    /// measured in come about every 10 ms.
    public func takeLevel() -> Float {
        InputLevel.of(meanSquare: Float(bitPattern: loudest.exchange(0, ordering: .relaxed)))
    }

    /// The input's last tenth of a second, oldest first, and its sample rate.
    public func recentAudio() -> (samples: [Float], sampleRate: Double) {
        recent.withLock { recent in
            (
                Array(recent.samples[recent.next...] + recent.samples[..<recent.next]),
                recent.sampleRate
            )
        }
    }

    /// Stops recording and returns what was recorded.
    public func stop() -> [Float] {
        stopEngine()
        return lock.withLock {
            isRecording = false
            defer { samples = [] }
            return samples
        }
    }

    private func stopEngine() {
        // Asking for the input node creates it, with the session's format at that moment.
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        if let meter {
            engine.detach(meter)
            self.meter = nil
        }
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private static func convert(
        _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
    ) -> [Float]? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        nonisolated(unsafe) var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = output.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

}

/// The microphone permission.
public enum MicrophonePermission {
    public enum Status: Sendable { case undetermined, denied, granted }

    public static var status: Status {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .undetermined
        }
    }

    /// Asks the user, if not asked before; returns whether the microphone may be used.
    public static func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

/// Reaches `installTap(onBus:bufferSize:format:block:)` without its deprecation warning.
///
/// macOS 27 and iOS 27 deprecate it in favour of `installTap(onBus:bufferSize:format:error:block:)`,
/// which Xcode 27.1 imports into Swift with an unusable `error` parameter (checked 2026-10-22).
/// Remove this once the replacement can be called from Swift.
private protocol TapInstalling {
    func installTap(
        onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock)
}

extension AVAudioNode: TapInstalling {}

/// A ring of the input's last tenth of a second, at the input's own rate.
private struct RecentAudio {
    var samples: [Float]
    /// Where the next sample goes, and so where the oldest is.
    var next = 0
    let sampleRate: Double

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        samples = Array(repeating: 0, count: max(Int(sampleRate / 10), 1))
    }
}
