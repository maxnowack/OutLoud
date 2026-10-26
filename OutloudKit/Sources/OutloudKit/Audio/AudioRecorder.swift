@preconcurrency import AVFoundation
import Foundation

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
    ///   - otherAudio: iOS: what the session does to other audio.
    ///   - level: Receives the input level, 0 to 1, from the audio thread.
    public func start(
        otherAudio: OtherAudio = .interrupt, level: (@Sendable (Float) -> Void)? = nil
    ) throws {
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
                level?(Self.level(of: converted))
            }
            tapInstalled = true
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

    private static func level(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        // About -50 dB to 0 dB mapped to 0...1.
        let decibels = 10 * log10(max(meanSquare, 1e-10))
        return max(0, min(1, (decibels + 50) / 50))
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
