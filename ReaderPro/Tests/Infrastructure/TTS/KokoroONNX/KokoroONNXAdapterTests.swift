import XCTest
@testable import ReaderPro

final class KokoroONNXAdapterTests: XCTestCase {

    // MARK: - Properties

    var sut: KokoroONNXAdapter!
    var mockEngine: MockKokoroONNXEngine!
    var mockPhonemizer: MockEspeakPhonemizer!
    var mockEmbeddingStore: MockVoiceEmbeddingStore!
    var tokenizer: KokoroTokenizer!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockEngine = MockKokoroONNXEngine()
        mockEngine._isLoaded = true
        mockPhonemizer = MockEspeakPhonemizer()
        mockEmbeddingStore = MockVoiceEmbeddingStore()
        tokenizer = KokoroTokenizer()

        sut = KokoroONNXAdapter(
            engine: mockEngine,
            phonemizer: mockPhonemizer,
            tokenizer: tokenizer,
            embeddingStore: mockEmbeddingStore,
            trimSilence: false // Disable trim for predictable test output
        )
    }

    override func tearDown() {
        sut = nil
        mockEngine = nil
        mockPhonemizer = nil
        mockEmbeddingStore = nil
        tokenizer = nil
        super.tearDown()
    }

    // MARK: - Provider

    func test_provider_shouldReturnKokoro() {
        XCTAssertEqual(sut.provider, .kokoro)
    }

    // MARK: - IsAvailable

    func test_isAvailable_whenEngineAndPhonemizerReady_shouldBeTrue() async {
        mockEngine._isLoaded = true
        mockPhonemizer._isAvailable = true

        let available = await sut.isAvailable

        XCTAssertTrue(available)
    }

    func test_isAvailable_whenEngineNotLoaded_shouldBeFalse() async {
        mockEngine._isLoaded = false
        mockPhonemizer._isAvailable = true

        let available = await sut.isAvailable

        XCTAssertFalse(available)
    }

    func test_isAvailable_whenPhonemizerUnavailable_shouldBeFalse() async {
        mockEngine._isLoaded = true
        mockPhonemizer._isAvailable = false

        let available = await sut.isAvailable

        XCTAssertFalse(available)
    }

    // MARK: - Synthesize Success

    func test_synthesize_shouldCallPhonemizer() async throws {
        // Arrange
        setupHappyPath()

        let text = try TextContent("hello world")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertTrue(mockPhonemizer.phonemizeCalled)
        XCTAssertEqual(mockPhonemizer.lastText, "hello world")
    }

    func test_synthesize_shouldCallEngineInfer() async throws {
        // Arrange
        setupHappyPath()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertTrue(mockEngine.inferCalled)
        // Tokens should be padded with 0s
        XCTAssertEqual(mockEngine.lastTokens?.first, 0)
        XCTAssertEqual(mockEngine.lastTokens?.last, 0)
    }

    func test_synthesize_shouldLoadEmbedding() async throws {
        // Arrange
        setupHappyPath()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig(voiceId: "ef_dora")
        let voice = makeVoice()

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertTrue(mockEmbeddingStore.loadEmbeddingCalled)
        XCTAssertEqual(mockEmbeddingStore.lastVoiceId, "ef_dora")
    }

    func test_synthesize_shouldReturnValidAudioData() async throws {
        // Arrange
        setupHappyPath()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act
        let audioData = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertFalse(audioData.data.isEmpty)
        XCTAssertGreaterThan(audioData.duration, 0)
    }

    func test_synthesize_shouldPassSpeedToEngine() async throws {
        // Arrange
        setupHappyPath()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig(speed: 1.5)
        let voice = makeVoice()

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertEqual(mockEngine.lastSpeed, 1.5)
    }

    // MARK: - Synthesize - Engine Not Loaded

    func test_synthesize_whenEngineNotLoaded_shouldLoadModel() async throws {
        // Arrange
        mockEngine._isLoaded = false
        setupHappyPath()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertTrue(mockEngine.loadModelCalled)
    }

    // MARK: - Synthesize Error Cases

    func test_synthesize_whenPhonemizationFails_shouldThrow() async throws {
        // Arrange
        mockPhonemizer.phonemizeError = EspeakPhonemizer.EspeakError.phonemizationFailed("test error")
        mockEmbeddingStore.embeddingToReturn = makeEmbedding()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch {
            // Expected
        }
    }

    func test_synthesize_whenInferenceFails_shouldThrow() async throws {
        // Arrange
        mockPhonemizer.phonemizeResult = "hello"
        mockEngine.inferError = KokoroONNXEngine.EngineError.inferenceFailed("test")
        mockEmbeddingStore.embeddingToReturn = makeEmbedding()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch {
            // Expected
        }
    }

    func test_synthesize_whenEmptyPhonemes_shouldThrow() async throws {
        // Arrange
        mockPhonemizer.phonemizeResult = ""
        mockEmbeddingStore.embeddingToReturn = makeEmbedding()

        let text = try TextContent("hello")
        let voiceConfig = try makeVoiceConfig()
        let voice = makeVoice()

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch {
            // Expected - empty phonemes
        }
    }

    // MARK: - Available Voices

    func test_availableVoices_shouldReturnVoices() async {
        mockEmbeddingStore.voiceIdsToReturn = ["af_bella", "ef_dora"]

        let voices = await sut.availableVoices()

        XCTAssertEqual(voices.count, 2)
        XCTAssertTrue(voices.allSatisfy { $0.provider == .kokoro })
    }

    func test_availableVoices_whenStoreErrors_shouldReturnDefaults() async {
        mockEmbeddingStore.availableVoiceIdsError = VoiceEmbeddingStore.VoiceEmbeddingError.fileNotFound("test")

        let voices = await sut.availableVoices()

        XCTAssertFalse(voices.isEmpty)
    }

    // MARK: - Helpers

    private func setupHappyPath() {
        // Phonemizer returns IPA characters that exist in the vocab
        mockPhonemizer.phonemizeResult = "hello" // h=50, e=47, l=54, l=54, o=57
        mockPhonemizer._isAvailable = true

        // Engine returns some audio
        mockEngine.inferResult = (0..<2400).map { i in
            0.5 * sinf(2.0 * .pi * 440.0 * Float(i) / 24000.0)
        }

        // Embedding store returns valid embedding
        mockEmbeddingStore.embeddingToReturn = makeEmbedding()
    }

    private func makeVoiceConfig(voiceId: String = "ef_dora", speed: Double = 1.0) throws -> VoiceConfiguration {
        VoiceConfiguration(
            voiceId: voiceId,
            speed: try VoiceConfiguration.Speed(speed)
        )
    }

    private func makeVoice() -> Voice {
        Voice(id: "ef_dora", name: "Dora", language: "es-ES", provider: .kokoro, isDefault: true)
    }

    private func makeEmbedding() -> VoiceEmbedding {
        // Create a dummy embedding with 510 style vectors of 256 floats each
        let styles = (0..<510).map { _ in
            [Float32](repeating: 0.1, count: 256)
        }
        return VoiceEmbedding(styles: styles)
    }
}

// MARK: - Mock VoiceEmbeddingStore

final class MockVoiceEmbeddingStore: VoiceEmbeddingStoreProtocol {
    var loadEmbeddingCalled = false
    var lastVoiceId: String?
    var embeddingToReturn: VoiceEmbedding?
    var loadEmbeddingError: Error?

    var voiceIdsToReturn: [String] = []
    var availableVoiceIdsError: Error?

    func loadEmbedding(voiceId: String) throws -> VoiceEmbedding {
        loadEmbeddingCalled = true
        lastVoiceId = voiceId

        if let error = loadEmbeddingError {
            throw error
        }

        guard let embedding = embeddingToReturn else {
            throw VoiceEmbeddingStore.VoiceEmbeddingError.voiceNotFound(voiceId)
        }

        return embedding
    }

    func availableVoiceIds() throws -> [String] {
        if let error = availableVoiceIdsError {
            throw error
        }
        return voiceIdsToReturn
    }
}
