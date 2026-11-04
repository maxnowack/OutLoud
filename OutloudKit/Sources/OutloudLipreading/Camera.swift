@preconcurrency import AVFoundation
import Foundation
import OutloudKit
import os

/// The camera while a recording runs: each frame's face points are found and its mouth cropped
/// as it arrives, on a queue of its own; nothing but the crops is kept (ADR 0034). The session
/// starts and stops on a queue of its own too: `startRunning` waits until the camera is on,
/// which on the main thread held back the recording's pill for as long.
final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Error { case noCamera, notAllowed }

    /// Touched only on `sessionQueue`, after `init`.
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "dev.nowack.outloud.camera.session")
    private let queue = DispatchQueue(label: "dev.nowack.outloud.camera")
    private static let log = Logger(subsystem: "dev.nowack.outloud", category: "lipreading")
    private let landmarks = FaceLandmarks()
    /// Touched only on `queue`.
    private var crop: MouthCrop?
    private var nextFrameTime: CMTime = .invalid
    /// Whether a frame came since the last start, and who waits for one; touched only on
    /// `queue`.
    private var delivered = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private static let frameInterval = CMTime(value: 1, timescale: 25)

    static var isAllowed: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    override init() {
        super.init()
        session.sessionPreset = .vga640x480
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
    }

    /// Turns the camera on without waiting for it, unless it runs, and with `cropping` begins
    /// a new crop of the frames that come; without, the frames are dropped until a start that
    /// crops them, which on a running camera comes at the next frame instead of a second later.
    func start(cropping: Bool = true) throws {
        guard Self.isAllowed else { throw Failure.notAllowed }
        guard let device = AVCaptureDevice.default(for: .video) else { throw Failure.noCamera }
        sessionQueue.async { [self] in
            let start = ContinuousClock.now
            if session.inputs.isEmpty {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else { throw Failure.noCamera }
                    session.beginConfiguration()
                    session.addInput(input)
                    session.commitConfiguration()
                } catch {
                    Self.log.error(
                        "camera did not start: \(String(describing: error), privacy: .public)")
                    return
                }
            }
            if cropping {
                queue.sync {
                    crop = MouthCrop()
                    nextFrameTime = .invalid
                    delivered = false
                }
            }
            guard !session.isRunning else { return }
            session.startRunning()
            Self.log.info("camera on in \(ContinuousClock.now - start, privacy: .public)")
        }
    }

    /// Stops the camera; the crops of the frames it delivered.
    func stop() async -> MouthFrames? {
        await finishCrop(stopping: true)
    }

    /// Ends the crop and leaves the camera running; the crops of the frames it delivered.
    func takeFrames() async -> MouthFrames? {
        await finishCrop(stopping: false)
    }

    private func finishCrop(stopping: Bool) async -> MouthFrames? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                if stopping { session.stopRunning() }
                queue.async {
                    let frames = self.crop?.finish()
                    self.crop = nil
                    self.firstFrameCame()
                    continuation.resume(returning: frames)
                }
            }
        }
    }

    /// Returns once the camera delivered a frame since it was started, or was stopped or did
    /// not start. Asked behind the start on `sessionQueue`, so that it sees that start's state.
    func firstFrame() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                queue.async { [self] in
                    if delivered || crop == nil {
                        continuation.resume()
                    } else {
                        waiting.append(continuation)
                    }
                }
            }
        }
    }

    /// On `queue`.
    private func firstFrameCame() {
        delivered = true
        for continuation in waiting { continuation.resume() }
        waiting = []
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let crop, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if !delivered { firstFrameCame() }
        // The model reads 25 frames a second; cameras run at 30 or 60. A frame is taken once
        // its time reaches the next 25th of a second, so that the crops follow real time.
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if nextFrameTime.isValid, time < nextFrameTime { return }
        nextFrameTime = (nextFrameTime.isValid ? nextFrameTime : time) + Self.frameInterval
        if time > nextFrameTime { nextFrameTime = time + Self.frameInterval }
        crop.append(GreyImage(lumaOf: buffer), points: landmarks.points(in: buffer))
    }
}
