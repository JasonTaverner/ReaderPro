import XCTest
import AVFoundation
@testable import ReaderPro

/// Tests para KokoroTTSAdapter usando mock de URLSession
final class KokoroTTSAdapterTests: XCTestCase {

    // MARK: - Properties

    var sut: KokoroTTSAdapter!
    var mockURLSession: MockURLSession!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        sut = KokoroTTSAdapter(
            baseURL: URL(string: "http://localhost:8880")!,
            urlSession: mockURLSession
        )
    }

    override func tearDown() {
        sut = nil
        mockURLSession = nil
        super.tearDown()
    }

    // MARK: - Provider Tests

    func test_provider_shouldReturnKokoro() {
        // Assert
        XCTAssertEqual(sut.provider, .kokoro)
    }

    // MARK: - IsAvailable Tests

    func test_isAvailable_whenHealthEndpointReturns200_shouldReturnTrue() async {
        // Arrange
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let isAvailable = await sut.isAvailable

        // Assert
        XCTAssertTrue(isAvailable)
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/health")
    }

    func test_isAvailable_whenHealthEndpointReturns500_shouldReturnFalse() async {
        // Arrange
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let isAvailable = await sut.isAvailable

        // Assert
        XCTAssertFalse(isAvailable)
    }

    func test_isAvailable_whenNetworkError_shouldReturnFalse() async {
        // Arrange
        mockURLSession.errorToThrow = URLError(.notConnectedToInternet)

        // Act
        let isAvailable = await sut.isAvailable

        // Assert
        XCTAssertFalse(isAvailable)
    }

    func test_isAvailable_whenTimeout_shouldReturnFalse() async {
        // Arrange
        mockURLSession.errorToThrow = URLError(.timedOut)

        // Act
        let isAvailable = await sut.isAvailable

        // Assert
        XCTAssertFalse(isAvailable)
    }

    // MARK: - AvailableVoices Tests

    func test_availableVoices_shouldReturnKokoroVoices() async {
        // Act
        let voices = await sut.availableVoices()

        // Assert
        XCTAssertFalse(voices.isEmpty)
        XCTAssertTrue(voices.allSatisfy { $0.provider == .kokoro })
    }

    func test_availableVoices_shouldIncludeCommonVoices() async {
        // Act
        let voices = await sut.availableVoices()

        // Assert
        let voiceIds = voices.map { $0.id }
        XCTAssertTrue(voiceIds.contains("ef_dora"))      // Spanish Female
        XCTAssertTrue(voiceIds.contains("em_alex"))      // Spanish Male
        XCTAssertTrue(voiceIds.contains("af_bella"))     // American Female
        XCTAssertTrue(voiceIds.contains("bf_emma"))      // British Female
    }

    func test_availableVoices_shouldHaveValidMetadata() async {
        // Act
        let voices = await sut.availableVoices()

        // Assert
        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty)
            XCTAssertFalse(voice.name.isEmpty)
            XCTAssertFalse(voice.language.isEmpty)
            XCTAssertEqual(voice.provider, .kokoro)
        }
    }

    // MARK: - Synthesize Tests

    func test_synthesize_withValidText_shouldReturnAudioData() async throws {
        // Arrange
        let text = try TextContent("Hello world")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        let audioData = try createTestWAVData()
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "audio/wav"]
        )

        // Act
        let result = try await sut.synthesize(
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.data.count, 0)
        XCTAssertGreaterThan(result.duration, 0)
    }

    func test_synthesize_shouldMakePOSTRequest() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        let audioData = try createTestWAVData()
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        _ = try await sut.synthesize(
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/synthesize")
    }

    func test_synthesize_shouldSendCorrectJSON() async throws {
        // Arrange
        let text = try TextContent("Hello Kokoro")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: try! VoiceConfiguration.Speed(1.5)
        )

        let audioData = try createTestWAVData()
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        _ = try await sut.synthesize(
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        let httpBody = mockURLSession.lastRequest?.httpBody
        XCTAssertNotNil(httpBody)

        let json = try JSONSerialization.jsonObject(with: httpBody!) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["text"] as? String, "Hello Kokoro")
        XCTAssertEqual(json?["voice"] as? String, "af")
        XCTAssertEqual(json?["speed"] as? Double, 1.5)
    }

    func test_synthesize_shouldSetContentTypeHeader() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        let audioData = try createTestWAVData()
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        _ = try await sut.synthesize(
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        let contentType = mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "application/json")
    }

    func test_synthesize_when500Error_shouldThrow() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            _ = try await sut.synthesize(
                text: text,
                voiceConfiguration: voiceConfig,
                voice: voice
            )
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    func test_synthesize_whenNetworkError_shouldThrow() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        mockURLSession.errorToThrow = URLError(.notConnectedToInternet)

        // Act & Assert
        do {
            _ = try await sut.synthesize(
                text: text,
                voiceConfiguration: voiceConfig,
                voice: voice
            )
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is URLError || error is InfrastructureError)
        }
    }

    func test_synthesize_withInvalidAudioData_shouldThrow() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        // Invalid audio data (not a valid WAV)
        mockURLSession.dataToReturn = Data([0x00, 0x01, 0x02])
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            _ = try await sut.synthesize(
                text: text,
                voiceConfiguration: voiceConfig,
                voice: voice
            )
            XCTFail("Should throw error for invalid audio data")
        } catch {
            // Expected - invalid audio data should fail
            XCTAssertTrue(error is InfrastructureError || error is DomainError)
        }
    }

    // MARK: - Integration-like Tests

    func test_synthesize_withLongText_shouldSucceed() async throws {
        // Arrange
        let longText = String(repeating: "palabra ", count: 100)
        let text = try TextContent(longText)
        let voice = Voice(
            id: "af",
            name: "American Female",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = VoiceConfiguration(
            voiceId: "af",
            speed: .normal
        )

        let audioData = try createTestWAVData(duration: 10.0)
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let result = try await sut.synthesize(
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        XCTAssertGreaterThan(result.duration, 0)
    }

    func test_synthesize_withDifferentVoices_shouldUseCorrectVoiceId() async throws {
        // Arrange
        let text = try TextContent("Test")
        let voiceConfig = VoiceConfiguration(
            voiceId: "bm",
            speed: .normal
        )

        let audioData = try createTestWAVData()
        mockURLSession.dataToReturn = audioData
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/synthesize")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let voices = [
            Voice(id: "af", name: "American Female", language: "en-US", provider: .kokoro, isDefault: false),
            Voice(id: "bm", name: "British Male", language: "en-GB", provider: .kokoro, isDefault: false),
            Voice(id: "bf", name: "British Female", language: "en-GB", provider: .kokoro, isDefault: false),
        ]

        // Act & Assert
        for voice in voices {
            _ = try await sut.synthesize(
                text: text,
                voiceConfiguration: VoiceConfiguration(
                    voiceId: voice.id,
                    speed: .normal
                ),
                voice: voice
            )

            let httpBody = mockURLSession.lastRequest?.httpBody
            let json = try JSONSerialization.jsonObject(with: httpBody!) as? [String: Any]
            XCTAssertEqual(json?["voice"] as? String, voice.id)
        }
    }

    // MARK: - Helper Methods

    /// Creates a simple WAV file data for testing
    private func createTestWAVData(duration: TimeInterval = 1.0) throws -> Data {
        let sampleRate: Int = 44100
        let numSamples = Int(duration * Double(sampleRate))
        let numChannels: Int = 1
        let bitsPerSample: Int = 16

        let dataSize = numSamples * numChannels * (bitsPerSample / 8)
        let fileSize = 44 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        wavData.append(Data(count: dataSize))

        return wavData
    }
}
