import CryptoKit
import Foundation

/// Computes the hub's etag of a file: SHA-256 for LFS files, the Git blob SHA-1 otherwise.
enum FileHashing {
    private static let chunkSize = 1 << 20

    static func matches(_ url: URL, _ hash: ModelFile.Hash) throws -> Bool {
        switch hash {
        case .sha256(let expected): try sha256(of: url) == expected
        case .gitBlob(let expected): try gitBlobSHA1(of: url) == expected
        }
    }

    static func sha256(of url: URL) throws -> String {
        var hasher = SHA256()
        try forEachChunk(of: url) { hasher.update(data: $0) }
        return hex(hasher.finalize())
    }

    static func gitBlobSHA1(of url: URL) throws -> String {
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(size)\u{0}".utf8))
        try forEachChunk(of: url) { hasher.update(data: $0) }
        return hex(hasher.finalize())
    }

    private static func forEachChunk(of url: URL, _ body: (Data) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            body(chunk)
        }
    }

    private static func hex<D: Digest>(_ digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
