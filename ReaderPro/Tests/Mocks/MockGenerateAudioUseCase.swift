import Foundation
@testable import ReaderPro

/// Mock de GenerateAudioUseCase para testing
@MainActor
final class MockGenerateAudioUseCase: GenerateAudioUseCaseProtocol {
    var executeCalled = false
    var lastRequest: GenerateAudioRequest?
    var responseToReturn: GenerateAudioResponse?
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse {
        executeCalled = true
        lastRequest = request

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        if let response = responseToReturn {
            return response
        }

        // Default response
        return GenerateAudioResponse(
            projectId: request.projectId,
            audioPath: "/default/audio.wav",
            duration: 5.0,
            status: .ready
        )
    }
}
