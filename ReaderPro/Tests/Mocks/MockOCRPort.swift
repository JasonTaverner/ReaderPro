import Foundation
@testable import ReaderPro

/// Mock de OCRPort para testing
final class MockOCRPort: OCRPort {

    // MARK: - Call Tracking

    var recognizeTextFromImageCalled = false
    var recognizeTextFromScreenCalled = false
    var lastImageData: ImageData?
    var lastScreenRegion: ScreenRegion?

    // MARK: - Stub Responses

    var recognizedTextToReturn: RecognizedText?
    var recognizedTextsToReturn: [RecognizedText] = []
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - isAvailable

    var isAvailableToReturn = true

    var isAvailable: Bool {
        get async { isAvailableToReturn }
    }

    // MARK: - supportedLanguages

    var supportedLanguagesToReturn: [String] = ["es-ES", "en-US"]

    var supportedLanguages: [String] {
        get async { supportedLanguagesToReturn }
    }

    // MARK: - recognizeText(from imageData:)

    func recognizeText(from imageData: ImageData) async throws -> RecognizedText {
        recognizeTextFromImageCalled = true
        lastImageData = imageData

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if let error = errorToThrow {
            throw error
        }

        guard let result = recognizedTextToReturn else {
            return try RecognizedText(text: "Mock recognized text", confidence: 0.95)
        }

        return result
    }

    // MARK: - recognizeText(from pdfPath:, pageNumber:)

    func recognizeText(from pdfPath: String, pageNumber: Int) async throws -> RecognizedText {
        if let error = errorToThrow { throw error }
        guard let result = recognizedTextToReturn else {
            return try RecognizedText(text: "PDF page \(pageNumber) text", confidence: 0.9)
        }
        return result
    }

    // MARK: - recognizeText(from pdfPath:)

    func recognizeText(from pdfPath: String) async throws -> [RecognizedText] {
        if let error = errorToThrow { throw error }
        return recognizedTextsToReturn
    }

    // MARK: - recognizeTextFromScreen

    func recognizeTextFromScreen(region: ScreenRegion?) async throws -> RecognizedText {
        recognizeTextFromScreenCalled = true
        lastScreenRegion = region

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if let error = errorToThrow {
            throw error
        }

        guard let result = recognizedTextToReturn else {
            return try RecognizedText(text: "Screen text", confidence: 0.9)
        }

        return result
    }
}
