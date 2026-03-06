import XCTest
@testable import ReaderPro

final class Qwen3TTSAdapterTests: XCTestCase {

    var sut: Qwen3TTSAdapter!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        sut = Qwen3TTSAdapter(
            baseURL: URL(string: "http://localhost:8890")!,
            urlSession: mockSession
        )
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Provider

    func test_provider_shouldBeQwen3() {
        XCTAssertEqual(sut.provider, .qwen3)
    }

    // MARK: - isAvailable

    func test_isAvailable_whenHealthReturns200_shouldReturnTrue() async {
        // Arrange
        let healthJSON = #"{"status":"ok","service":"qwen3-tts-mlx"}"#
        mockSession.dataToReturn = healthJSON.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/health")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        let available = await sut.isAvailable

        // Assert
        XCTAssertTrue(available)
    }

    func test_isAvailable_whenHealthReturns503_shouldReturnFalse() async {
        // Arrange
        mockSession.dataToReturn = Data()
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/health")!,
            statusCode: 503, httpVersion: nil, headerFields: nil
        )

        // Act
        let available = await sut.isAvailable

        // Assert
        XCTAssertFalse(available)
    }

    func test_isAvailable_whenNetworkError_shouldReturnFalse() async {
        // Arrange
        mockSession.errorToThrow = URLError(.cannotConnectToHost)

        // Act
        let available = await sut.isAvailable

        // Assert
        XCTAssertFalse(available)
    }

    // MARK: - availableVoices

    func test_availableVoices_shouldReturn9Voices() async {
        let voices = await sut.availableVoices()
        XCTAssertEqual(voices.count, 9)
    }

    func test_availableVoices_shouldIncludeVivian() async {
        let voices = await sut.availableVoices()
        XCTAssertTrue(voices.contains { $0.id == "Vivian" })
    }

    func test_availableVoices_shouldIncludeAllPremiumSpeakers() async {
        let voices = await sut.availableVoices()
        let ids = Set(voices.map(\.id))
        XCTAssertTrue(ids.contains("Vivian"))
        XCTAssertTrue(ids.contains("Serena"))
        XCTAssertTrue(ids.contains("Uncle_Fu"))
        XCTAssertTrue(ids.contains("Dylan"))
        XCTAssertTrue(ids.contains("Eric"))
        XCTAssertTrue(ids.contains("Ryan"))
        XCTAssertTrue(ids.contains("Aiden"))
        XCTAssertTrue(ids.contains("Ono_Anna"))
        XCTAssertTrue(ids.contains("Sohee"))
    }

    func test_availableVoices_shouldAllBeQwen3Provider() async {
        let voices = await sut.availableVoices()
        for voice in voices {
            XCTAssertEqual(voice.provider, .qwen3)
        }
    }

    func test_availableVoices_shouldHaveOneDefault() async {
        let voices = await sut.availableVoices()
        let defaults = voices.filter(\.isDefault)
        XCTAssertEqual(defaults.count, 1)
    }

    // MARK: - synthesize

    func test_synthesize_withValidResponse_shouldReturnAudioData() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Hello world")
        let voiceConfig = VoiceConfiguration(voiceId: "Vivian", speed: .normal)
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act
        let audioData = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertFalse(audioData.data.isEmpty)
    }

    func test_synthesize_shouldSendCorrectJSON() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Hola mundo")
        let voiceConfig = VoiceConfiguration(
            voiceId: "Serena", speed: try .init(1.5),
            instruct: "Speak happily"
        )
        let voice = Voice(id: "Serena", name: "Serena", language: "multi", provider: .qwen3, isDefault: false)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let sentRequest = mockSession.lastRequest
        XCTAssertNotNil(sentRequest)
        XCTAssertEqual(sentRequest?.httpMethod, "POST")
        XCTAssertTrue(sentRequest?.url?.path.contains("synthesize") ?? false)

        let body = try JSONSerialization.jsonObject(with: sentRequest!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["text"] as? String, "Hola mundo")
        XCTAssertEqual(body["speaker"] as? String, "Serena")
        XCTAssertEqual(body["speed"] as? Double, 1.5)
        XCTAssertEqual(body["instruct"] as? String, "Speak happily")
    }

    func test_synthesize_withoutInstruct_shouldNotIncludeInstructInJSON() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Hello")
        let voiceConfig = VoiceConfiguration(voiceId: "Vivian", speed: .normal)
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let body = try JSONSerialization.jsonObject(with: mockSession.lastRequest!.httpBody!) as! [String: Any]
        // instruct should not be present when nil
        XCTAssertNil(body["instruct"] as? String)
    }

    func test_synthesize_whenServerReturns500_shouldThrow() async {
        // Arrange
        let errorJSON = #"{"error":"Internal error"}"#
        mockSession.dataToReturn = errorJSON.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 500, httpVersion: nil, headerFields: nil
        )

        let text = try! TextContent("Hello")
        let voiceConfig = VoiceConfiguration(voiceId: "Vivian", speed: .normal)
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    func test_synthesize_whenConnectionRefused_shouldThrowServerNotRunning() async {
        // Arrange
        mockSession.errorToThrow = URLError(.cannotConnectToHost)

        let text = try! TextContent("Hello")
        let voiceConfig = VoiceConfiguration(voiceId: "Vivian", speed: .normal)
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch let error as InfrastructureError {
            if case .ttsServerNotRunning = error {
                // Expected
            } else {
                XCTFail("Expected ttsServerNotRunning but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_synthesize_whenTimeout_shouldThrowServerTimeout() async {
        // Arrange
        mockSession.errorToThrow = URLError(.timedOut)

        let text = try! TextContent("Hello")
        let voiceConfig = VoiceConfiguration(voiceId: "Vivian", speed: .normal)
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act & Assert
        do {
            _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)
            XCTFail("Should throw")
        } catch let error as InfrastructureError {
            if case .ttsServerTimeout = error {
                // Expected
            } else {
                XCTFail("Expected ttsServerTimeout but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - VoiceDesign Mode

    func test_synthesize_withVoiceDesignInstruct_shouldSendVoiceDesignMode() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Hola mundo")
        let voiceConfig = VoiceConfiguration(
            voiceId: "Vivian", speed: .normal,
            voiceDesignInstruct: "A warm female voice with native Castilian Spanish accent",
            voiceDesignLanguage: "es"
        )
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let body = try JSONSerialization.jsonObject(with: mockSession.lastRequest!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["mode"] as? String, "voice_design")
        XCTAssertEqual(body["instruct"] as? String, "A warm female voice with native Castilian Spanish accent")
        XCTAssertEqual(body["language"] as? String, "es")
        // In voice_design mode, speaker should not be in the body
        XCTAssertNil(body["speaker"])
    }

    func test_synthesize_withoutVoiceDesignInstruct_shouldSendCustomVoiceMode() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Hello world")
        let voiceConfig = VoiceConfiguration(
            voiceId: "Ryan", speed: .normal,
            instruct: "Speak happily"
        )
        let voice = Voice(id: "Ryan", name: "Ryan", language: "multi", provider: .qwen3, isDefault: false)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let body = try JSONSerialization.jsonObject(with: mockSession.lastRequest!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["mode"] as? String, "custom_voice")
        XCTAssertEqual(body["speaker"] as? String, "Ryan")
        XCTAssertEqual(body["instruct"] as? String, "Speak happily")
        XCTAssertEqual(body["language"] as? String, "auto")
    }

    func test_synthesize_voiceDesignMode_shouldNotIncludeSpeaker() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Bonjour le monde")
        let voiceConfig = VoiceConfiguration(
            voiceId: "Vivian", speed: try .init(1.2),
            voiceDesignInstruct: "A cheerful young French female voice with Parisian accent",
            voiceDesignLanguage: "fr"
        )
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let body = try JSONSerialization.jsonObject(with: mockSession.lastRequest!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["mode"] as? String, "voice_design")
        XCTAssertNil(body["speaker"])
        XCTAssertEqual(body["language"] as? String, "fr")
        XCTAssertEqual(body["speed"] as? Double, 1.2)
        XCTAssertEqual(body["text"] as? String, "Bonjour le monde")
    }

    func test_synthesize_voiceDesignMode_withoutLanguage_shouldFallbackToAuto() async throws {
        // Arrange
        let wavData = makeMinimalWAVData()
        mockSession.dataToReturn = wavData
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/synthesize")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        let text = try TextContent("Test text")
        let voiceConfig = VoiceConfiguration(
            voiceId: "Vivian", speed: .normal,
            voiceDesignInstruct: "A custom voice description"
        )
        let voice = Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true)

        // Act
        _ = try await sut.synthesize(text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        let body = try JSONSerialization.jsonObject(with: mockSession.lastRequest!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["mode"] as? String, "voice_design")
        XCTAssertEqual(body["language"] as? String, "auto")
    }

    // MARK: - fetchModelStatus

    func test_fetchModelStatus_whenModelLoaded_shouldReturnModelName() async throws {
        // Arrange
        let json = #"{"loaded_model":"custom_voice","loaded_model_id":"mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit","load_count":1}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/models")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        let status = try await sut.fetchModelStatus()

        // Assert
        XCTAssertEqual(status.loadedModel, "custom_voice")
        XCTAssertEqual(status.loadedModelId, "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit")
    }

    func test_fetchModelStatus_whenNoModelLoaded_shouldReturnNil() async throws {
        // Arrange
        let json = #"{"loaded_model":null,"loaded_model_id":null,"load_count":0}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/models")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        let status = try await sut.fetchModelStatus()

        // Assert
        XCTAssertNil(status.loadedModel)
        XCTAssertNil(status.loadedModelId)
    }

    func test_fetchModelStatus_whenServerDown_shouldThrow() async {
        // Arrange
        mockSession.errorToThrow = URLError(.cannotConnectToHost)

        // Act & Assert
        do {
            _ = try await sut.fetchModelStatus()
            XCTFail("Should throw")
        } catch {
            // Expected
        }
    }

    func test_fetchModelStatus_shouldCallModelsEndpoint() async throws {
        // Arrange
        let json = #"{"loaded_model":null,"loaded_model_id":null,"load_count":0}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/models")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        _ = try await sut.fetchModelStatus()

        // Assert
        XCTAssertTrue(mockSession.lastRequest?.url?.path.contains("models") ?? false)
    }

    // MARK: - unloadModel

    func test_unloadModel_whenModelWasLoaded_shouldReturnUnloadedName() async throws {
        // Arrange
        let json = #"{"status":"ok","unloaded":"custom_voice","message":"Model unloaded"}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/unload")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        let unloaded = try await sut.unloadModel()

        // Assert
        XCTAssertEqual(unloaded, "custom_voice")
    }

    func test_unloadModel_whenNoModelLoaded_shouldReturnNil() async throws {
        // Arrange
        let json = #"{"status":"ok","unloaded":null,"message":"No model was loaded"}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/unload")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        let unloaded = try await sut.unloadModel()

        // Assert
        XCTAssertNil(unloaded)
    }

    func test_unloadModel_shouldSendPOST() async throws {
        // Arrange
        let json = #"{"status":"ok","unloaded":null,"message":"No model was loaded"}"#
        mockSession.dataToReturn = json.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/unload")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        _ = try await sut.unloadModel()

        // Assert
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(mockSession.lastRequest?.url?.path.contains("unload") ?? false)
    }

    func test_unloadModel_whenServerDown_shouldThrow() async {
        // Arrange
        mockSession.errorToThrow = URLError(.cannotConnectToHost)

        // Act & Assert
        do {
            _ = try await sut.unloadModel()
            XCTFail("Should throw")
        } catch {
            // Expected
        }
    }

    // MARK: - Helpers

    /// Creates minimal WAV header + silence (44 header bytes + 48000 bytes = 1 second at 24kHz 16-bit mono)
    private func makeMinimalWAVData() -> Data {
        var data = Data()

        let sampleRate: UInt32 = 24000
        let numSamples: UInt32 = 24000  // 1 second
        let dataSize = numSamples * 2   // 16-bit = 2 bytes per sample
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // Mono
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: (sampleRate * 2).littleEndian) { Array($0) }) // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(Data(count: Int(dataSize))) // silence

        return data
    }
}
