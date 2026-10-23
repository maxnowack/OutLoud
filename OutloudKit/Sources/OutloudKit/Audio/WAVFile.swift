import Foundation

/// Reads and writes mono 16-bit PCM WAV files, the format of the history's recordings.
public enum WAVFile {
    public enum Error: Swift.Error, Equatable {
        case unsupportedFormat
    }

    public static func write(samples: [Float], sampleRate: Int, to url: URL) throws {
        var data = Data()
        let byteCount = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))  // PCM
        data.append(littleEndian: UInt16(1))  // mono
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * 2))
        data.append(littleEndian: UInt16(2))
        data.append(littleEndian: UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: UInt32(byteCount))
        data.reserveCapacity(data.count + byteCount)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            data.append(littleEndian: Int16((clamped * Float(Int16.max)).rounded()))
        }
        try data.write(to: url, options: [.atomic, HistoryStore.fileProtection])
    }

    /// Reads a mono 16-bit PCM WAV file as samples between -1 and 1.
    public static func read(_ url: URL) throws -> (samples: [Float], sampleRate: Int) {
        let data = try Data(contentsOf: url)
        guard data.count >= 44, data.prefix(4) == Data("RIFF".utf8) else {
            throw Error.unsupportedFormat
        }
        var offset = 12
        var sampleRate = 0
        var channels = 0
        var bits = 0
        while offset + 8 <= data.count {
            let id = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let size = Int(data.littleEndian(UInt32.self, at: offset + 4))
            let body = offset + 8
            if id == "fmt " {
                channels = Int(data.littleEndian(UInt16.self, at: body + 2))
                sampleRate = Int(data.littleEndian(UInt32.self, at: body + 4))
                bits = Int(data.littleEndian(UInt16.self, at: body + 14))
            } else if id == "data" {
                guard channels == 1, bits == 16 else { throw Error.unsupportedFormat }
                let end = min(body + size, data.count)
                var samples = [Float]()
                samples.reserveCapacity((end - body) / 2)
                var index = body
                while index + 1 < end {
                    let value = Int16(bitPattern: data.littleEndian(UInt16.self, at: index))
                    samples.append(Float(value) / Float(Int16.max))
                    index += 2
                }
                return (samples, sampleRate)
            }
            offset = body + size + (size % 2)
        }
        throw Error.unsupportedFormat
    }
}

extension Data {
    fileprivate mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    fileprivate func littleEndian<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
        var value: T = 0
        Swift.withUnsafeMutableBytes(of: &value) { buffer in
            buffer.copyBytes(
                from: self[(startIndex + offset)..<(startIndex + offset + MemoryLayout<T>.size)])
        }
        return T(littleEndian: value)
    }
}
