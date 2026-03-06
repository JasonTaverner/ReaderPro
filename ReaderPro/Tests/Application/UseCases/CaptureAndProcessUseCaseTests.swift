import XCTest
@testable import ReaderPro

/// Tests para CaptureAndProcessUseCase usando TDD
/// Flujo: Captura de pantalla → OCR → Guardar AudioEntry → (Opcional) Generar Audio
@MainActor
final class CaptureAndProcessUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: CaptureAndProcessUseCase!
    var mockScreenCapture: MockScreenCapturePort!
    var mockOCR: MockOCRPort!
    var mockSaveEntry: MockSaveAudioEntryUseCase!
    var mockTTS: MockTTSPort!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockScreenCapture = MockScreenCapturePort()
        mockOCR = MockOCRPort()
        mockSaveEntry = MockSaveAudioEntryUseCase()
        mockTTS = MockTTSPort()

        sut = CaptureAndProcessUseCase(
            screenCapturePort: mockScreenCapture,
            ocrPort: mockOCR,
            saveAudioEntryUseCase: mockSaveEntry,
            ttsPort: mockTTS
        )
    }

    override func tearDown() {
        sut = nil
        mockScreenCapture = nil
        mockOCR = nil
        mockSaveEntry = nil
        mockTTS = nil
        super.tearDown()
    }

    // MARK: - Happy Path Tests

    func test_execute_shouldCaptureScreen() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockScreenCapture.captureInteractiveCalled)
    }

    func test_execute_shouldRunOCROnCapturedImage() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let imageData = Data(repeating: 0xAA, count: 200)
        mockScreenCapture.capturedImageToReturn = try CapturedImage(
            imageData: imageData,
            temporaryPath: "/tmp/test.png"
        )

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockOCR.recognizeTextFromImageCalled)
        XCTAssertEqual(mockOCR.lastImageData?.data, imageData)
    }

    func test_execute_shouldSaveEntryWithRecognizedText() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let recognizedText = try RecognizedText(text: "Texto capturado de pantalla", confidence: 0.95)
        mockOCR.recognizedTextToReturn = recognizedText

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockSaveEntry.executeCalled)
        XCTAssertEqual(mockSaveEntry.lastRequest?.projectId, projectId)
        XCTAssertEqual(mockSaveEntry.lastRequest?.text, "Texto capturado de pantalla")
    }

    func test_execute_shouldReturnRecognizedTextAndConfidence() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let recognizedText = try RecognizedText(text: "Resultado OCR", confidence: 0.88)
        mockOCR.recognizedTextToReturn = recognizedText

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.recognizedText, "Resultado OCR")
        XCTAssertEqual(response.confidence, 0.88, accuracy: 0.01)
    }

    func test_execute_shouldPassImagePathToSaveEntry() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockScreenCapture.capturedImageToReturn = try CapturedImage(
            imageData: Data(repeating: 0xFF, count: 100),
            temporaryPath: "/tmp/screenshot_123.png"
        )

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockSaveEntry.lastRequest?.imagePath, "/tmp/screenshot_123.png")
    }

    // MARK: - Generate Audio Tests

    func test_execute_withGenerateAudioFalse_shouldNotCallTTS() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let request = CaptureAndProcessRequest(projectId: projectId, generateAudio: false)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertFalse(mockTTS.synthesizeCalled)
    }

    func test_execute_withGenerateAudioTrue_shouldCallTTS() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockOCR.recognizedTextToReturn = try RecognizedText(text: "Generate this audio", confidence: 0.9)
        mockTTS.audioDataToReturn = try AudioData(data: Data(repeating: 1, count: 512), duration: 5.0)

        let request = CaptureAndProcessRequest(projectId: projectId, generateAudio: true)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockTTS.synthesizeCalled)
    }

    func test_execute_withGenerateAudioTrue_shouldSaveAudioDataInEntry() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioBytes = Data(repeating: 42, count: 1024)
        mockOCR.recognizedTextToReturn = try RecognizedText(text: "Audio text", confidence: 0.9)
        mockTTS.audioDataToReturn = try AudioData(data: audioBytes, duration: 8.5)

        let request = CaptureAndProcessRequest(projectId: projectId, generateAudio: true)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockSaveEntry.lastRequest?.audioData, audioBytes)
        XCTAssertEqual(mockSaveEntry.lastRequest?.audioDuration, 8.5)
    }

    // MARK: - Error Handling Tests

    func test_execute_whenCaptureFailsWithCancel_shouldPropagateError() async {
        // Arrange
        let projectId = Identifier<Project>()
        mockScreenCapture.errorToThrow = ScreenCaptureError.userCancelled

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is ScreenCaptureError)
        }
    }

    func test_execute_whenOCRFails_shouldPropagateError() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockOCR.errorToThrow = OCRError.noTextFound

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }

    func test_execute_whenSaveEntryFails_shouldPropagateError() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockSaveEntry.errorToThrow = ApplicationError.projectNotFound

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is ApplicationError)
        }
    }

    func test_execute_whenTTSFails_shouldPropagateError() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockOCR.recognizedTextToReturn = try RecognizedText(text: "Will fail TTS", confidence: 0.9)
        mockTTS.errorToThrow = NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "TTS failed"])

        let request = CaptureAndProcessRequest(projectId: projectId, generateAudio: true)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            // TTS error should propagate
            XCTAssertFalse(mockSaveEntry.executeCalled, "Should not save if TTS fails")
        }
    }

    // MARK: - Response Mapping Tests

    func test_execute_shouldReturnEntryIdFromSaveResponse() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockSaveEntry.responseToReturn = SaveAudioEntryResponse(
            entryId: "test-entry-id",
            entryNumber: 5,
            textPath: "Project/005.txt",
            audioPath: "Project/005.wav",
            imagePath: "Project/005.png"
        )

        let request = CaptureAndProcessRequest(projectId: projectId)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entryId, "test-entry-id")
        XCTAssertEqual(response.entryNumber, 5)
    }
}
