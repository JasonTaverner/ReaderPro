import Foundation
@testable import ReaderPro

/// Mock de ListProjectsUseCase para testing
@MainActor
final class MockListProjectsUseCase: ListProjectsUseCaseProtocol {
    var listCalled = false
    var projectsToReturn: [ProjectSummary] = []
    var errorToThrow: Error?
    var delayResponse = false

    func execute(_ request: ListProjectsRequest) async throws -> ListProjectsResponse {
        listCalled = true

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        return ListProjectsResponse(projects: projectsToReturn)
    }
}
