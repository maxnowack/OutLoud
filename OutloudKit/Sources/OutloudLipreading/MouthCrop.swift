import CoreVideo
import Foundation
import OutloudKit
import Vision

/// The four points a face is aligned on, in pixels with the origin at the top left: the eye on
/// the image's left, the eye on its right, the nose (the nostrils' row), the mouth's centre.
public struct FacePoints: Sendable, Equatable {
    public var points: [SIMD2<Double>]

    public init(_ points: [SIMD2<Double>]) {
        precondition(points.count == 4)
        self.points = points
    }

    var mouth: SIMD2<Double> { points[3] }

    static func + (a: FacePoints, b: FacePoints) -> FacePoints {
        FacePoints(zip(a.points, b.points).map { $0 + $1 })
    }

    static func * (a: FacePoints, s: Double) -> FacePoints { FacePoints(a.points.map { $0 * s }) }

    var centroid: SIMD2<Double> { points.reduce(.zero, +) / 4 }
}

/// A similarity transform (rotation, uniform scale, translation): p′ = A p + t.
struct Similarity: Equatable {
    var a: Double  // s cos θ
    var b: Double  // s sin θ
    var t: SIMD2<Double>

    func apply(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(a * p.x - b * p.y, b * p.x + a * p.y) + t
    }

    func inverse() -> Similarity {
        let d = a * a + b * b
        let (ia, ib) = (a / d, -b / d)
        let it = -SIMD2(ia * t.x - ib * t.y, ib * t.x + ia * t.y)
        return Similarity(a: ia, b: ib, t: it)
    }

    /// The least-squares similarity from `source` to `target`.
    static func fitting(_ source: [SIMD2<Double>], to target: [SIMD2<Double>]) -> Similarity {
        let n = Double(source.count)
        let ms = source.reduce(.zero, +) / n
        let mt = target.reduce(.zero, +) / n
        var (sxx, sxy, norm) = (0.0, 0.0, 0.0)
        for (s, t) in zip(source, target) {
            let (ds, dt) = (s - ms, t - mt)
            sxx += ds.x * dt.x + ds.y * dt.y
            sxy += ds.x * dt.y - ds.y * dt.x
            norm += ds.x * ds.x + ds.y * ds.y
        }
        let (a, b) = (sxx / norm, sxy / norm)
        return Similarity(a: a, b: b, t: mt - SIMD2(a * ms.x - b * ms.y, b * ms.x + a * ms.y))
    }
}

/// A greyscale image, row-major, one byte a pixel.
public struct GreyImage: Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, bytesPerRow: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixels = pixels
    }

    /// The luma plane of a full-range 4:2:0 buffer, which is the grey image.
    public init(lumaOf buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!.assumingMemoryBound(
            to: UInt8.self)
        pixels = Array(UnsafeBufferPointer(start: base, count: bytesPerRow * height))
    }

    /// Bilinear sample; black outside the image, as OpenCV's constant border.
    func sample(_ p: SIMD2<Double>) -> UInt8 {
        let (x0, y0) = (Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
        let (fx, fy) = (p.x - Double(x0), p.y - Double(y0))
        func at(_ x: Int, _ y: Int) -> Double {
            x >= 0 && y >= 0 && x < width && y < height ? Double(pixels[y * bytesPerRow + x]) : 0
        }
        let top = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
        let bottom = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
        return UInt8(clamping: Int((top * (1 - fy) + bottom * fy).rounded()))
    }
}

/// Auto-AVSR's mouth crop (`preparation/detectors/*/video_process.py`): the face points are
/// smoothed over ±6 frames, the frame is aligned on the mean face in a 256 × 256 space, and
/// the 96 × 96 square around the mouth is cut out. It runs as the frames arrive, holding only
/// the frames whose window is not complete yet.
public final class MouthCrop {
    public static let size = MouthFrames.size
    static let margin = 6
    static let holding = 50
    /// The mean face's four points in the 256 × 256 space.
    static let reference: [SIMD2<Double>] = [
        [102.0739, 94.2723], [156.3613, 93.5782], [129.0037, 135.9034], [129.3134, 157.823],
    ]

    private var images: [GreyImage?] = []
    private var points: [FacePoints?] = []
    private var cropped: [UInt8] = []
    private var next = 0

    public init() {}

    /// Adds a frame and the face points found in it, or nil where no face was found.
    public func append(_ image: GreyImage, points found: FacePoints?) {
        images.append(image)
        points.append(found)
        cropReady(finished: false)
    }

    /// The crops of every frame so far; nil if no frame had a face.
    public func finish() -> MouthFrames? {
        guard points.contains(where: { $0 != nil }) else { return nil }
        cropReady(finished: true)
        return MouthFrames(pixels: cropped, frames: next)
    }

    /// Crops each frame whose smoothing window is known, and drops its image.
    private func cropReady(finished: Bool) {
        guard let firstFound = points.firstIndex(where: { $0 != nil }) else { return }
        let lastFound = points.lastIndex(where: { $0 != nil })!
        // Frames without a face are interpolated between their neighbours; before the first
        // and after the last found they take the nearest.
        func filled(_ i: Int) -> FacePoints {
            if let p = points[i] { return p }
            if i < firstFound { return points[firstFound]! }
            if i > lastFound { return points[lastFound]! }
            let before = points[..<i].lastIndex(where: { $0 != nil })!
            let after = points[(i + 1)...].firstIndex(where: { $0 != nil })!
            let w = Double(i - before) / Double(after - before)
            return points[before]! * (1 - w) + points[after]! * w
        }
        let count = points.count
        // A frame is final once its window reaches no further than the last frame with a face.
        // A long stretch without a face is not held beyond `holding` frames (a frame of 720p
        // is about 1 MB): its frames take the nearest face, as at the end.
        var known = finished ? count : max(0, min(count, lastFound + 1) - Self.margin)
        if !finished { known = max(known, count - Self.holding) }
        while next < known {
            let i = next
            let m = finished ? min(Self.margin, i, count - 1 - i) : min(Self.margin, i)
            let window = (i - m...i + m).map(filled)
            var smooth = window.dropFirst().reduce(window[0], +) * (1 / Double(window.count))
            let shift = filled(i).centroid - smooth.centroid
            smooth = FacePoints(smooth.points.map { $0 + shift })
            cropped += Self.crop(images[i]!, smooth)
            images[i] = nil
            next += 1
        }
    }

    static func crop(_ image: GreyImage, _ points: FacePoints) -> [UInt8] {
        let align = Similarity.fitting(points.points, to: reference)
        let mouth = align.apply(points.mouth)
        let (x0, y0) = (Int(mouth.x.rounded()) - size / 2, Int(mouth.y.rounded()) - size / 2)
        let back = align.inverse()
        var out = [UInt8](repeating: 0, count: size * size)
        for v in 0..<size {
            for u in 0..<size {
                let x = x0 + u
                let y = y0 + v
                // The aligned space ends at 256: OpenCV's warp leaves the rest black.
                guard x >= 0, y >= 0, x < 256, y < 256 else { continue }
                out[v * size + u] = image.sample(back.apply(SIMD2(Double(x), Double(y))))
            }
        }
        return out
    }
}

/// Finds the four face points with Vision's face landmarks, on the device.
public struct FaceLandmarks: Sendable {
    /// Whether a frame with more than one face counts as one without a face.
    let alone: Bool

    public init(alone: Bool = false) { self.alone = alone }

    public func points(in buffer: CVPixelBuffer) -> FacePoints? {
        let request = VNDetectFaceLandmarksRequest()
        guard (try? VNImageRequestHandler(cvPixelBuffer: buffer).perform([request])) != nil,
            !alone || request.results?.count == 1,
            let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
            let landmarks = face.landmarks, let e1 = landmarks.leftEye, let e2 = landmarks.rightEye,
            let nose = landmarks.nose, let outer = landmarks.outerLips,
            let inner = landmarks.innerLips
        else { return nil }
        let size = CGSize(
            width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        // Vision's origin is at the bottom left.
        func pixels(_ region: VNFaceLandmarkRegion2D) -> [SIMD2<Double>] {
            region.pointsInImage(imageSize: size).map { SIMD2($0.x, size.height - $0.y) }
        }
        func mean(_ p: [SIMD2<Double>]) -> SIMD2<Double> { p.reduce(.zero, +) / Double(p.count) }
        let eyes = [mean(pixels(e1)), mean(pixels(e2))].sorted { $0.x < $1.x }
        let nostrils = mean(Array(pixels(nose).sorted { $0.y > $1.y }.prefix(3)))
        return FacePoints([eyes[0], eyes[1], nostrils, mean(pixels(outer) + pixels(inner))])
    }
}
