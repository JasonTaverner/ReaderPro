import Foundation
@testable import ReaderPro

/// Mock implementation of GenerateAudioForEntryUseCaseProtocol for testing
@MainActor
final class MockGenerateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol {

    // MARK: - Call Tracking

    var executeCalled = false
    var lastRequest: GenerateAudioForEntryRequest?

    // MARK: - Stubbed Responses

    var responseToReturn: GenerateAudioForEntryResponse?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - Protocol Implementation

    func execute(_ request: GenerateAudioForEntryRequest) async throws -> GenerateAudioForEntryResponse {
        executeCalled = true
        lastRequest = request

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        return responseToReturn ?? GenerateAudioForEntryResponse(
            entryId: request.entryId,
            audioPath: "mock_audio_path.wav",
            duration: 5.0
        )
    }

    // MARK: - Reset

    func reset() {
        executeCalled = false
        lastRequest = nil
        responseToReturn = nil
        errorToThrow = nil
        delayResponse = false
    }
}
