import Foundation
import ZIPFoundation

/// Represents a voice embedding for Kokoro TTS
/// Shape: (510, 1, 256) float32 — one style vector per token position
struct VoiceEmbedding {
    /// All 510 style vectors, each of length 256
    let styles: [[Float32]]

    /// Get the style vector for a given token count
    /// - Parameter tokenCount: Number of tokens (before padding)
    /// - Returns: Style vector of length 256, shape [1, 256] for ONNX input
    func styleForTokenCount(_ tokenCount: Int) -> [Float32] {
        let index = min(tokenCount, styles.count - 1)
        return styles[index]
    }
}

/// Protocol for loading voice embeddings
protocol VoiceEmbeddingStoreProtocol {
    func loadEmbedding(voiceId: String) throws -> VoiceEmbedding
    func availableVoiceIds() throws -> [String]
}

/// Loads and caches voice embeddings from a .npz (voices.bin) file
/// The .npz format is a ZIP archive containing .npy files, one per voice
final class VoiceEmbeddingStore: VoiceEmbeddingStoreProtocol {

    // MARK: - Errors

    enum VoiceEmbeddingError: LocalizedError {
        case fileNotFound(String)
        case voiceNotFound(String)
        case invalidNpyData(String)
        case invalidShape(expected: [Int], got: [Int])

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Voices file not found: \(path)"
            case .voiceNotFound(let voiceId):
                return "Voice '\(voiceId)' not found in voices file"
            case .invalidNpyData(let reason):
                return "Invalid NPY data: \(reason)"
            case .invalidShape(let expected, let got):
                return "Invalid embedding shape: expected \(expected), got \(got)"
            }
        }
    }

    // MARK: - Properties

    private let voicesURL: URL
    private var cache: [String: VoiceEmbedding] = [:]
    private var voiceIdCache: [String]?
    private let lock = NSLock()

    // MARK: - Init

    init(voicesURL: URL) {
        self.voicesURL = voicesURL
    }

    /// Convenience init to find voices file in common locations
    convenience init() throws {
        // Search in bundle resources and known paths
        let searchPaths = [
            Bundle.main.url(forResource: "voices-v1.0", withExtension: "bin"),
            Bundle.main.url(forResource: "voices", withExtension: "bin"),
        ].compactMap { $0 }

        if let url = searchPaths.first {
            self.init(voicesURL: url)
            return
        }

        // Check scripts/Resources path
        let projectPaths = [
            "scripts/Resources/Models/kokoro/voices-v1.0.bin",
            "voices.bin"
        ]

        for relativePath in projectPaths {
            let url = URL(fileURLWithPath: relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                self.init(voicesURL: url)
                return
            }
        }

        throw VoiceEmbeddingError.fileNotFound("Could not find voices.bin in any search path")
    }

    // MARK: - VoiceEmbeddingStoreProtocol

    func loadEmbedding(voiceId: String) throws -> VoiceEmbedding {
        lock.lock()
        defer { lock.unlock() }

        // Check cache
        if let cached = cache[voiceId] {
            return cached
        }

        // Load from NPZ
        let npyData = try extractNpy(voiceId: voiceId)
        let npyArray = try NpyParser.parse(npyData)

        // Validate shape: expected (510, 1, 256)
        guard npyArray.shape.count == 3,
              npyArray.shape[0] == 510,
              npyArray.shape[1] == 1,
              npyArray.shape[2] == 256 else {
            throw VoiceEmbeddingError.invalidShape(
                expected: [510, 1, 256],
                got: npyArray.shape
            )
        }

        // Reshape: (510, 1, 256) → 510 arrays of 256 floats
        // Data is stored in row-major (C order): dimension 2 varies fastest
        var styles: [[Float32]] = []
        styles.reserveCapacity(510)

        for i in 0..<510 {
            let startIdx = i * 256 // skip dim 1 since it's 1
            let endIdx = startIdx + 256
            styles.append(Array(npyArray.data[startIdx..<endIdx]))
        }

        let embedding = VoiceEmbedding(styles: styles)
        cache[voiceId] = embedding
        return embedding
    }

    func availableVoiceIds() throws -> [String] {
        lock.lock()
        defer { lock.unlock() }

        if let cached = voiceIdCache {
            return cached
        }

        guard let archive = Archive(url: voicesURL, accessMode: .read) else {
            throw VoiceEmbeddingError.fileNotFound(voicesURL.path)
        }

        let ids = archive.compactMap { entry -> String? in
            let name = entry.path
            guard name.hasSuffix(".npy") else { return nil }
            // Remove .npy extension to get voice ID
            return String(name.dropLast(4))
        }.sorted()

        voiceIdCache = ids
        return ids
    }

    // MARK: - Private

    /// Extract a single .npy file from the .npz archive
    private func extractNpy(voiceId: String) throws -> Data {
        guard let archive = Archive(url: voicesURL, accessMode: .read) else {
            throw VoiceEmbeddingError.fileNotFound(voicesURL.path)
        }

        let entryName = "\(voiceId).npy"
        guard let entry = archive[entryName] else {
            throw VoiceEmbeddingError.voiceNotFound(voiceId)
        }

        var npyData = Data()
        _ = try archive.extract(entry) { chunk in
            npyData.append(chunk)
        }

        return npyData
    }
}
