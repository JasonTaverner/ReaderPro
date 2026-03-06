import Foundation
@testable import ReaderPro

/// Mock de SaveAudioEntryUseCase para testing
@MainActor
final class MockSaveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol {

    // MARK: - Call Tracking

    var executeCalled = false
    var executeCallCount = 0
    var lastRequest: SaveAudioEntryRequest?

    // MARK: - Stub Responses

    var responseToReturn: SaveAudioEntryResponse?
    var errorToThrow: Error?
    var delayResponse = false

    /// Custom handler for per-call control (overrides responseToReturn/errorToThrow)
    var executeHandler: ((SaveAudioEntryRequest) throws -> SaveAudioEntryResponse)?

    // MARK: - Protocol Implementation

    func execute(_ request: SaveAudioEntryRequest) async throws -> SaveAudioEntryResponse {
        executeCalled = true
        executeCallCount += 1
        lastRequest = request

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let handler = executeHandler {
            return try handler(request)
        }

        if let error = errorToThrow {
            throw error
        }

        guard let response = responseToReturn else {
            return SaveAudioEntryResponse(
                entryId: "001",
                entryNumber: 1,
                textPath: "General/001.txt",
                audioPath: "General/001.wav",
                imagePath: nil
            )
        }

        return response
    }
}
