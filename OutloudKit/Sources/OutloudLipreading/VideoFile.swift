import AVFoundation
import Foundation
import OutloudKit
import simd

/// The mouth crops of a video file, for the `outloud` CLI and the training data: the file must
/// run at 25 frames a second, as the camera does while recording.
public enum VideoFile {
    ///
    /// For training data, `faces` is the share of frames that must show one face alone — with
    /// two, the speaker is not known — with at least `eyes` pixels between the eyes; a video whose
    /// first second falls short is given up early, so that a harvest spends little on pieces
    /// without a speaker in close-up.
    public static func mouthFrames(of url: URL, faces share: Double = 0, eyes minimum: Double = 0)
        async throws -> MouthFrames?
    {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let crop = MouthCrop()
        let landmarks = FaceLandmarks(alone: share > 0)
        var (frames, faces) = (0, 0)
        func enough() -> Bool { Double(faces) >= share * Double(frames) }
        while let sample = try await provider.next() {
            sample.withUnsafeSampleBuffer { sample in
                guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
                let points = landmarks.points(in: buffer)
                if let p = points?.points, simd_distance(p[0], p[1]) >= minimum { faces += 1 }
                frames += 1
                crop.append(GreyImage(lumaOf: buffer), points: points)
            }
            if frames == MouthFrames.framesPerSecond, !enough() {
                reader.cancelReading()
                return nil
            }
        }
        return enough() ? crop.finish() : nil
    }
}

extension MouthFrames {
    /// The frames from `start` to `end` seconds.
    public func slice(from start: Double, to end: Double) -> MouthFrames {
        let a = max(0, Int(start * Double(Self.framesPerSecond)))
        let b = min(frames, Int(end * Double(Self.framesPerSecond)))
        let size = Self.size * Self.size
        return MouthFrames(pixels: Array(pixels[(a * size)..<(b * size)]), frames: b - a)
    }
}
