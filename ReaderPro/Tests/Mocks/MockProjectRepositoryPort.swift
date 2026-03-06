import Foundation
@testable import ReaderPro

/// Mock del ProjectRepositoryPort para tests
/// Permite verificar interacciones y simular respuestas
final class MockProjectRepositoryPort: ProjectRepositoryPort {

    // MARK: - Call Tracking

    var saveCalled = false
    var saveCallCount = 0
    var lastSavedProject: Project?

    var findByIdCalled = false
    var lastFindByIdQuery: Identifier<Project>?

    var findAllCalled = false
    var searchCalled = false
    var lastSearchQuery: String?

    var deleteCalled = false
    var lastDeletedId: Identifier<Project>?

    var findByStatusCalled = false
    var lastStatusQuery: ProjectStatus?

    var findCreatedAfterCalled = false
    var lastDateQuery: Date?

    // MARK: - Stub Responses

    var projectToReturn: Project?
    var projectsToReturn: [Project] = []
    var errorToThrow: Error?
    var saveErrorToThrow: Error?  // Specific error for save() only

    // MARK: - ProjectRepositoryPort Implementation

    func save(_ project: Project) async throws {
        saveCalled = true
        saveCallCount += 1
        lastSavedProject = project

        if let error = saveErrorToThrow ?? errorToThrow {
            throw error
        }
    }

    func findById(_ id: Identifier<Project>) async throws -> Project? {
        findByIdCalled = true
        lastFindByIdQuery = id

        if let error = errorToThrow {
            throw error
        }

        return projectToReturn
    }

    func findAll() async throws -> [Project] {
        findAllCalled = true

        if let error = errorToThrow {
            throw error
        }

        return projectsToReturn
    }

    func search(query: String) async throws -> [Project] {
        searchCalled = true
        lastSearchQuery = query

        if let error = errorToThrow {
            throw error
        }

        return projectsToReturn
    }

    func delete(_ id: Identifier<Project>) async throws {
        deleteCalled = true
        lastDeletedId = id

        if let error = errorToThrow {
            throw error
        }
    }

    func findByStatus(_ status: ProjectStatus) async throws -> [Project] {
        findByStatusCalled = true
        lastStatusQuery = status

        if let error = errorToThrow {
            throw error
        }

        return projectsToReturn
    }

    func findCreatedAfter(_ date: Date) async throws -> [Project] {
        findCreatedAfterCalled = true
        lastDateQuery = date

        if let error = errorToThrow {
            throw error
        }

        return projectsToReturn
    }

    // MARK: - Helper Methods

    func reset() {
        saveCalled = false
        saveCallCount = 0
        lastSavedProject = nil
        findByIdCalled = false
        lastFindByIdQuery = nil
        findAllCalled = false
        searchCalled = false
        lastSearchQuery = nil
        deleteCalled = false
        lastDeletedId = nil
        findByStatusCalled = false
        lastStatusQuery = nil
        findCreatedAfterCalled = false
        lastDateQuery = nil
        projectToReturn = nil
        projectsToReturn = []
        errorToThrow = nil
    }
}
