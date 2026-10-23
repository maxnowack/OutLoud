import FluidAudio
import Foundation

/// Reads an audio file of any format Core Audio knows as 16 kHz mono samples.
public enum AudioFile {
    public static func samples(of url: URL) throws -> [Float] {
        try AudioConverter().resampleAudioFile(url)
    }
}
