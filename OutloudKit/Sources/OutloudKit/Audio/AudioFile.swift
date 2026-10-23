import FluidAudio
import Foundation

/// Reads an audio file of any format Core Audio knows as 16 kHz mono samples.
public enum AudioFile {
    public static func samples(of url: URL) throws -> [Float] {
        try AudioConverter().resampleAudioFile(url)
    }

    /// Reads audio handed over as data — by a shortcut, say — through a temporary file, whose
    /// extension tells Core Audio the format. The name comes from outside: only a plain
    /// extension of letters and digits is kept, so that it cannot point the file elsewhere.
    public static func samples(of data: Data, named name: String) throws -> [Float] {
        let file = FileManager.default.temporaryDirectory.appending(
            path: "\(UUID().uuidString).\(fileExtension(of: name))")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try samples(of: file)
    }

    static func fileExtension(of name: String) -> String {
        let candidate = (name as NSString).pathExtension.lowercased()
        let isPlain =
            (1...8).contains(candidate.count)
            && candidate.unicodeScalars.allSatisfy {
                ("a"..."z").contains($0) || ("0"..."9").contains($0)
            }
        return isPlain ? candidate : "m4a"
    }
}
