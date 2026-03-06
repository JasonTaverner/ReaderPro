import Foundation
@testable import ReaderPro

/// Mock de DeleteProjectUseCase para testing
@MainActor
final class MockDeleteProjectUseCase: DeleteProjectUseCaseProtocol {
    var deleteCalled = false
    var lastDeletedId: Identifier<Project>?
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: DeleteProjectRequest) async throws -> DeleteProjectResponse {
        deleteCalled = true
        lastDeletedId = request.projectId

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        return DeleteProjectResponse(
            projectId: request.projectId,
            projectName: "Test Project",
            deleted: true,
            audioDeleted: false
        )
    }
}
