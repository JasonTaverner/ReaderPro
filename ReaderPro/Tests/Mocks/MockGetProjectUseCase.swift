import Foundation
@testable import ReaderPro

/// Mock de GetProjectUseCase para testing
@MainActor
final class MockGetProjectUseCase: GetProjectUseCaseProtocol {
    var executeCalled = false
    var lastProjectId: Identifier<Project>?
    var projectToReturn: Project?
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: GetProjectRequest) async throws -> GetProjectResponse {
        executeCalled = true
        lastProjectId = request.projectId

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        guard let project = projectToReturn else {
            throw ApplicationError.projectNotFound
        }

        return GetProjectResponse(project: project)
    }
}
