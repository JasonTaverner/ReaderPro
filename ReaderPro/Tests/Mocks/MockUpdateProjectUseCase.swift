import Foundation
@testable import ReaderPro

/// Mock de UpdateProjectUseCase para testing
@MainActor
final class MockUpdateProjectUseCase: UpdateProjectUseCaseProtocol {
    var executeCalled = false
    var lastRequest: UpdateProjectRequest?
    var responseToReturn: UpdateProjectResponse?
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: UpdateProjectRequest) async throws -> UpdateProjectResponse {
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
        return UpdateProjectResponse(
            projectId: request.projectId,
            name: request.name ?? "Updated",
            text: request.text ?? "",
            status: .draft,
            audioPath: nil,
            voiceId: request.voiceId ?? "",
            voiceName: "",
            voiceLanguage: "",
            voiceProvider: .native,
            speed: request.speed ?? 1.0,
            updatedAt: Date()
        )
    }
}
