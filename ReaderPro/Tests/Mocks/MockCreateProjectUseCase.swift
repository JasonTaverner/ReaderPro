import Foundation
@testable import ReaderPro

/// Mock de CreateProjectUseCase para testing
@MainActor
final class MockCreateProjectUseCase: CreateProjectUseCaseProtocol {
    var executeCalled = false
    var lastRequest: CreateProjectRequest?
    var responseToReturn: CreateProjectResponse?
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse {
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
        return CreateProjectResponse(
            projectId: Identifier<Project>(),
            projectName: request.name ?? "Test",
            status: .draft,
            createdAt: Date()
        )
    }
}
