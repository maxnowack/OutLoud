import CoreAudio
import Foundation
import os

/// Listens to the sound some processes put out, through a private Core Audio tap that leaves
/// it audible, and keeps the peak of every stretch it delivers (ADR 0025). Needs the user's
/// permission to record system audio; macOS asks for it the first time.
final class OutputTap: Sendable {
    /// When each stretch ended and the loudest sample in it.
    private let peaks = OSAllocatedUnfairLock(initialState: [(ContinuousClock.Instant, Float)]())
    private let tap: AudioObjectID
    private let device: AudioObjectID
    private let proc: AudioDeviceIOProcID

    /// Starts listening to `processes`, Core Audio's objects of them; `nil` where the tap or its
    /// device cannot be made.
    init?(processes: [AudioObjectID]) {
        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.isPrivate = true
        description.muteBehavior = .unmuted
        var tap = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tap) == noErr else { return nil }
        let settings: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Outloud output level",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        var device = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(settings as CFDictionary, &device) == noErr else {
            AudioHardwareDestroyProcessTap(tap)
            return nil
        }
        let peaks = peaks
        var proc: AudioDeviceIOProcID?
        let created = AudioDeviceCreateIOProcIDWithBlock(&proc, device, nil) { _, input, _, _, _ in
            var peak: Float = 0
            for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self)
                for index in 0..<Int(buffer.mDataByteSize) / MemoryLayout<Float>.size {
                    peak = max(peak, abs(samples[index]))
                }
            }
            let stretch = (ContinuousClock.now, peak)
            peaks.withLock { $0.append(stretch) }
        }
        guard created == noErr, let proc, AudioDeviceStart(device, proc) == noErr else {
            if let proc { AudioDeviceDestroyIOProcID(device, proc) }
            AudioHardwareDestroyAggregateDevice(device)
            AudioHardwareDestroyProcessTap(tap)
            return nil
        }
        self.tap = tap
        self.device = device
        self.proc = proc
    }

    /// The stretches delivered since the last call.
    func takePeaks() -> [(ContinuousClock.Instant, Float)] {
        peaks.withLock { peaks in
            defer { peaks.removeAll() }
            return peaks
        }
    }

    func stop() {
        AudioDeviceStop(device, proc)
        AudioDeviceDestroyIOProcID(device, proc)
        AudioHardwareDestroyAggregateDevice(device)
        AudioHardwareDestroyProcessTap(tap)
    }
}
