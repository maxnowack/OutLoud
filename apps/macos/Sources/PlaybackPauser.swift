import AppKit
import CoreAudio
import OutloudKit
import OutloudUI
import SwiftUI
import os

/// Pauses what plays while a dictation records, and lets it play on afterwards (ADR 0025).
///
/// macOS offers no public way to pause another app's playback, nor to ask whether one plays.
/// This listens to the apps that put out sound and, when they sound, sends the pause command of
/// the private MediaRemote framework, which pauses the app that plays now and does nothing when
/// none does. Only when they fall silent after it does the play/pause media key play them on
/// afterwards, so that the key never starts the last player; when they keep sounding, the pill
/// says so.
@MainActor
@Observable
final class PlaybackPauser {
    /// Whether an app still sounds after the pause command, which the microphone may pick up.
    private(set) var hearsBackgroundAudio = false
    /// Whether this pauser paused a player, and so owes the key press.
    @ObservationIgnored private var paused = false
    /// Listens to the apps before and after the pause command.
    @ObservationIgnored private var watch: Task<Void, Never>?

    private static let log = Logger(subsystem: "dev.nowack.outloud", category: "PlaybackPauser")

    /// Before a recording starts: pauses what plays. Needs Accessibility access to post the key
    /// that plays it on.
    func pauseIfPlaying() {
        guard !paused, watch == nil, AXIsProcessTrusted(), let sendCommand = Self.sendCommand
        else {
            Self.log.info(
                "Not paused: trusted \(AXIsProcessTrusted()), MediaRemote \(Self.sendCommand != nil)"
            )
            return
        }
        let playing = Self.appsPuttingOutSound()
        guard !playing.isEmpty else {
            Self.log.info("Not paused: no app puts out sound")
            return
        }
        guard !Self.systemAudioDenied else {
            // Nothing tells whether the pause took, so the user plays on by hand.
            Self.log.info("Pausing without playing on: recording system audio is not allowed")
            _ = sendCommand(Self.pauseCommand, nil)
            return
        }
        guard let tap = OutputTap(processes: Array(playing.values)) else {
            Self.log.error("Not paused: the output tap could not be made")
            return
        }
        let names = Self.names(of: Set(playing.keys))
        watch = Task { [weak self] in
            await self?.listen(to: tap, names: names, sendCommand: sendCommand)
            tap.stop()
            if !Task.isCancelled { self?.watch = nil }
        }
    }

    /// Once the recording has ended: plays on what this pauser paused.
    func resume() {
        watch?.cancel()
        watch = nil
        hearsBackgroundAudio = false
        guard paused else { return }
        paused = false
        Self.pressPlayPause()
    }

    /// Sends the pause command if the apps sound, and judges by their sound whether it took.
    private func listen(to tap: OutputTap, names: String, sendCommand: SendCommand) async {
        let listening = ContinuousClock.now
        var audible = false
        while !audible, ContinuousClock.now - listening < Self.listenFor {
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            audible = tap.takePeaks().contains { PauseCheck.isAudible(peak: $0.1) }
        }
        guard audible else {
            Self.log.info("Not paused: \(names, privacy: .public) put out silence")
            return
        }
        _ = sendCommand(Self.pauseCommand, nil)
        let start = ContinuousClock.now
        var check = PauseCheck()
        while true {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            for (time, peak) in tap.takePeaks() { check.record(peak: peak, elapsed: time - start) }
            let elapsed = ContinuousClock.now - start
            let after = Int(elapsed / .milliseconds(1))
            switch check.verdict(elapsed: elapsed) {
            case .paused:
                paused = true
                Self.log.info(
                    "Paused \(names, privacy: .public): silent \(after) ms after the command")
                return
            case .stillPlaying:
                withAnimation(Tokens.standard) { hearsBackgroundAudio = true }
                Self.log.info("Not playing on: \(names, privacy: .public) still sound")
                return
            case nil: continue
            }
        }
    }

    /// How long Outloud listens for the apps' sound before the command; the tap's first audio
    /// takes a few hundredths of a second.
    private static let listenFor: Duration = .milliseconds(300)

    // MARK: MediaRemote

    private typealias SendCommand = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
    /// `kMRPause` of MediaRemote's command enumeration.
    private static let pauseCommand: UInt32 = 1
    /// Without the framework, or with the function gone in a later macOS, nothing is paused.
    private static let sendCommand: SendCommand? = {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW),
            let symbol = dlsym(handle, "MRMediaRemoteSendCommand")
        else { return nil }
        return unsafeBitCast(symbol, to: SendCommand.self)
    }()

    // MARK: Permission

    private typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int32
    /// TCC's preflight, private as MediaRemote: macOS has no public way to ask whether the user
    /// allowed recording system audio, and a tap without it hears silence.
    private static let preflight: Preflight? = {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW),
            let symbol = dlsym(handle, "TCCAccessPreflight")
        else { return nil }
        return unsafeBitCast(symbol, to: Preflight.self)
    }()

    /// Whether the user declined recording system audio. Not yet asked, or with nothing to ask,
    /// it is not: the first tap asks.
    static var systemAudioDenied: Bool {
        preflight?("kTCCServiceAudioCapture" as CFString, nil) == 1
    }

    // MARK: Core Audio

    /// The processes of apps — not Outloud's, not daemons such as the system sounds' — that put
    /// out sound now. A browser plays in a helper of its own, which macOS does not list as an app.
    private static func appsPuttingOutSound() -> [pid_t: AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
            return [:]
        }
        var processes = [AudioObjectID](
            repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr
        else { return [:] }
        let own = ProcessInfo.processInfo.processIdentifier
        return Dictionary(
            uniqueKeysWithValues: processes.compactMap { process in
                guard
                    value(of: kAudioProcessPropertyIsRunningOutput, of: process, as: UInt32.self)
                        != 0,
                    let pid = value(of: kAudioProcessPropertyPID, of: process, as: pid_t.self),
                    pid != own, isPartOfAnApp(pid)
                else { return nil }
                return (pid, process)
            })
    }

    /// Whether the process runs from inside an app or an XPC service — a helper such as a
    /// browser's or WebKit's —, not from a folder of daemons such as `/usr/sbin`.
    private static func isPartOfAnApp(_ pid: pid_t) -> Bool {
        guard let path = executablePath(of: pid) else { return false }
        return path.contains(".app/") || path.contains(".xpc/")
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    /// The executables' names of `pids`, for the log: which processes count as playing.
    private static func names(of pids: Set<pid_t>) -> String {
        pids.map { executablePath(of: $0).map { URL(filePath: $0).lastPathComponent } ?? "\($0)" }
            .sorted().joined(separator: ", ")
    }

    private static func value<T: FixedWidthInteger>(
        of selector: AudioObjectPropertySelector, of object: AudioObjectID, as type: T.Type
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value = T.zero
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    // MARK: Media key

    /// The play/pause media key, as the keyboard sends it: a system-defined event of subtype 8
    /// with the key in the high half of `data1` and down (0xA) or up (0xB) beneath it.
    private static func pressPlayPause() {
        // NX_KEYTYPE_PLAY in <IOKit/hidsystem/ev_keymap.h>.
        let playKey = 16
        for state in [0xA, 0xB] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)), timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: (playKey << 16) | (state << 8),
                data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
