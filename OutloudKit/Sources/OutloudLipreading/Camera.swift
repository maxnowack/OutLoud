@preconcurrency import AVFoundation
import Foundation
import OutloudKit

/// The camera while a recording runs: each frame's face points are found and its mouth cropped
/// as it arrives, on a queue of its own; nothing but the crops is kept (ADR 0034).
final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Error { case noCamera, notAllowed }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.nowack.outloud.camera")
    private let landmarks = FaceLandmarks()
    /// Touched only on `queue`.
    private var crop: MouthCrop?
    private var nextFrameTime: CMTime = .invalid
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

    func start() throws {
        guard Self.isAllowed else { throw Failure.notAllowed }
        guard let device = AVCaptureDevice.default(for: .video) else { throw Failure.noCamera }
        session.beginConfiguration()
        if session.inputs.isEmpty {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw Failure.noCamera }
            session.addInput(input)
        }
        session.commitConfiguration()
        queue.sync {
            crop = MouthCrop()
            nextFrameTime = .invalid
        }
        session.startRunning()
    }

    /// Stops the camera; the crops of the frames it delivered.
    func stop() async -> MouthFrames? {
        session.stopRunning()
        return await withCheckedContinuation { continuation in
            queue.async {
                let frames = self.crop?.finish()
                self.crop = nil
                continuation.resume(returning: frames)
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let crop, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // The model reads 25 frames a second; cameras run at 30 or 60. A frame is taken once
        // its time reaches the next 25th of a second, so that the crops follow real time.
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if nextFrameTime.isValid, time < nextFrameTime { return }
        nextFrameTime = (nextFrameTime.isValid ? nextFrameTime : time) + Self.frameInterval
        if time > nextFrameTime { nextFrameTime = time + Self.frameInterval }
        crop.append(GreyImage(lumaOf: buffer), points: landmarks.points(in: buffer))
    }
}
