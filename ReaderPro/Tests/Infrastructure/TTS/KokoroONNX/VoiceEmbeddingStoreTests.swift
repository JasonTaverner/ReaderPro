import XCTest
@testable import ReaderPro

final class VoiceEmbeddingStoreTests: XCTestCase {

    // MARK: - Tests with real voices.bin

    /// Tests that use the real voices.bin file (integration-like)
    /// These tests are skipped if the file is not available

    private func voicesURL() -> URL? {
        // Check known paths
        let paths = [
            "/Users/jesuscruz/repos2/ReaderPro/scripts/Resources/Models/kokoro/voices-v1.0.bin",
            "/Users/jesuscruz/repos2/ReaderPro/voices.bin"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    func test_loadEmbedding_validVoice_shouldReturnCorrectShape() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        // Arrange
        let store = VoiceEmbeddingStore(voicesURL: url)

        // Act
        let embedding = try store.loadEmbedding(voiceId: "af_bella")

        // Assert
        XCTAssertEqual(embedding.styles.count, 510)
        XCTAssertEqual(embedding.styles[0].count, 256)
    }

    func test_loadEmbedding_spanishVoice_shouldWork() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)

        let embedding = try store.loadEmbedding(voiceId: "ef_dora")

        XCTAssertEqual(embedding.styles.count, 510)
        XCTAssertEqual(embedding.styles[0].count, 256)
    }

    func test_loadEmbedding_invalidVoice_shouldThrow() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)

        XCTAssertThrowsError(try store.loadEmbedding(voiceId: "nonexistent_voice")) { error in
            guard case VoiceEmbeddingStore.VoiceEmbeddingError.voiceNotFound = error else {
                XCTFail("Expected voiceNotFound, got \(error)")
                return
            }
        }
    }

    func test_loadEmbedding_shouldCache() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)

        // Load twice
        let first = try store.loadEmbedding(voiceId: "af_bella")
        let second = try store.loadEmbedding(voiceId: "af_bella")

        // Should return same data
        XCTAssertEqual(first.styles[0], second.styles[0])
        XCTAssertEqual(first.styles[100], second.styles[100])
    }

    func test_availableVoiceIds_shouldReturn54Voices() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)

        let ids = try store.availableVoiceIds()

        XCTAssertEqual(ids.count, 54)
        XCTAssertTrue(ids.contains("af_bella"))
        XCTAssertTrue(ids.contains("ef_dora"))
        XCTAssertTrue(ids.contains("em_santa"))
        XCTAssertTrue(ids.contains("em_alex"))
    }

    func test_availableVoiceIds_shouldBeSorted() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)
        let ids = try store.availableVoiceIds()

        XCTAssertEqual(ids, ids.sorted())
    }

    // MARK: - VoiceEmbedding Tests

    func test_styleForTokenCount_shouldReturnCorrectIndex() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)
        let embedding = try store.loadEmbedding(voiceId: "af_bella")

        // Token count 10 should return style at index 10
        let style = embedding.styleForTokenCount(10)
        XCTAssertEqual(style.count, 256)
        XCTAssertEqual(style, embedding.styles[10])
    }

    func test_styleForTokenCount_exceedingMax_shouldClamp() throws {
        guard let url = voicesURL() else {
            throw XCTSkip("voices.bin not found")
        }

        let store = VoiceEmbeddingStore(voicesURL: url)
        let embedding = try store.loadEmbedding(voiceId: "af_bella")

        // Token count 600 should clamp to 509
        let style = embedding.styleForTokenCount(600)
        XCTAssertEqual(style.count, 256)
        XCTAssertEqual(style, embedding.styles[509])
    }

    // MARK: - Error Cases

    func test_loadEmbedding_fileNotFound_shouldThrow() {
        let store = VoiceEmbeddingStore(voicesURL: URL(fileURLWithPath: "/nonexistent/file.bin"))

        XCTAssertThrowsError(try store.loadEmbedding(voiceId: "test"))
    }
}
