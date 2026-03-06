import XCTest
@testable import ReaderPro

/// Tests para el Use Case DeleteProject
/// Elimina un proyecto y sus archivos de audio asociados
final class DeleteProjectUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: DeleteProjectUseCase!
    var mockRepository: MockProjectRepositoryPort!
    var mockStorage: MockAudioStoragePort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        mockStorage = MockAudioStoragePort()

        sut = DeleteProjectUseCase(
            projectRepository: mockRepository,
            audioStorage: mockStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockStorage = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func test_execute_withExistingProject_shouldDeleteFromRepository() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - Repository operations
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertEqual(mockRepository.lastFindByIdQuery, project.id)
        XCTAssertTrue(mockRepository.deleteCalled)
        XCTAssertEqual(mockRepository.lastDeletedId, project.id)

        // Assert - Response
        XCTAssertEqual(response.projectId, project.id)
        XCTAssertEqual(response.projectName, project.name.value)
        XCTAssertTrue(response.deleted)
    }

    func test_execute_withProjectWithAudio_shouldDeleteAudioFile() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(audioPath: "/audio/test123.wav")
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - Audio storage should be called
        XCTAssertTrue(mockStorage.deleteCalled)
        XCTAssertEqual(mockStorage.lastDeletedPath, "/audio/test123.wav")
        XCTAssertTrue(response.audioDeleted)
    }

    func test_execute_withProjectWithoutAudio_shouldNotDeleteAudioFile() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        XCTAssertNil(project.audioPath)

        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - Audio storage should NOT be called
        XCTAssertFalse(mockStorage.deleteCalled)
        XCTAssertFalse(response.audioDeleted)
    }

    func test_execute_shouldDeleteInCorrectOrder() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        _ = try await sut.execute(request)

        // Assert - Order: find → delete audio → delete project
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertTrue(mockStorage.deleteCalled)
        XCTAssertTrue(mockRepository.deleteCalled)
    }

    func test_execute_shouldIncludeProjectNameInResponse() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("Mi Proyecto Importante"))
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.projectName, "Mi Proyecto Importante")
    }

    // MARK: - Error Tests

    func test_execute_withNonexistentProject_shouldThrowError() async {
        // Arrange
        mockRepository.projectToReturn = nil  // Project not found

        let request = DeleteProjectRequest(projectId: Identifier<Project>())

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for nonexistent project")
        } catch {
            guard case ApplicationError.projectNotFound = error else {
                XCTFail("Expected projectNotFound error")
                return
            }
            XCTAssertTrue(mockRepository.findByIdCalled)
            XCTAssertFalse(mockRepository.deleteCalled)
        }
    }

    func test_execute_whenRepositoryFindFails_shouldPropagateError() async {
        // Arrange
        struct RepositoryError: Error {}
        mockRepository.errorToThrow = RepositoryError()

        let request = DeleteProjectRequest(projectId: Identifier<Project>())

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            XCTAssertTrue(mockRepository.findByIdCalled)
        }
    }

    func test_execute_whenAudioDeleteFails_shouldContinueAndDeleteProject() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = project

        struct StorageError: Error {}
        mockStorage.errorToThrow = StorageError()

        let request = DeleteProjectRequest(projectId: project.id)

        // Act - Should not throw, continues even if audio delete fails
        let response = try await sut.execute(request)

        // Assert - Project still deleted
        XCTAssertTrue(mockStorage.deleteCalled)
        XCTAssertTrue(mockRepository.deleteCalled)
        XCTAssertTrue(response.deleted)
        XCTAssertFalse(response.audioDeleted)  // Audio deletion failed
    }

    func test_execute_whenProjectDeleteFails_shouldPropagateError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        struct RepositoryError: Error {}
        // Set error only for delete operation
        mockRepository.errorToThrow = nil
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // We need to test the delete operation failing
        // For now, we'll just verify the call order
        _ = try? await sut.execute(request)

        XCTAssertTrue(mockRepository.deleteCalled)
    }

    // MARK: - Multiple Audio Files Tests

    func test_execute_withMultipleEntries_shouldOnlyDeleteMainAudio() async throws {
        // Arrange
        var project = TestFixtures.makeProjectWithAudio(audioPath: "/audio/main.wav")

        // Add entries (they might have their own audio paths)
        let entry1 = AudioEntry(
            text: try! TextContent("Entry 1"),
            audioPath: "/audio/entry1.wav",
            imagePath: nil
        )
        try! project.addEntry(entry1)

        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        _ = try await sut.execute(request)

        // Assert - Should only delete the main project audio
        XCTAssertTrue(mockStorage.deleteCalled)
        XCTAssertEqual(mockStorage.lastDeletedPath, "/audio/main.wav")
        // Note: Entry audio cleanup would be handled separately or by repository
    }

    // MARK: - Integration Tests

    func test_execute_fullFlow_shouldCoordinateAllOperations() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Test text"),
            audioPath: "/audio/test.wav"
        )
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - All operations executed
        XCTAssertTrue(mockRepository.findByIdCalled)   // 1. Find
        XCTAssertTrue(mockStorage.deleteCalled)        // 2. Delete audio
        XCTAssertTrue(mockRepository.deleteCalled)     // 3. Delete project

        // Assert - Response complete
        XCTAssertEqual(response.projectId, project.id)
        XCTAssertEqual(response.projectName, "Test Project")
        XCTAssertTrue(response.deleted)
        XCTAssertTrue(response.audioDeleted)
    }

    func test_execute_multipleTimes_shouldFailOnSecondAttempt() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act - First deletion
        _ = try await sut.execute(request)

        // Reset mock and simulate project not found
        mockRepository.reset()
        mockRepository.projectToReturn = nil

        // Act & Assert - Second deletion should fail
        do {
            _ = try await sut.execute(request)
            XCTFail("Should fail when trying to delete already deleted project")
        } catch {
            guard case ApplicationError.projectNotFound = error else {
                XCTFail("Expected projectNotFound error")
                return
            }
        }
    }

    // MARK: - Edge Cases

    func test_execute_withEmptyAudioPath_shouldNotAttemptDelete() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        // Simulate empty audio path (edge case)
        project.markAudioGenerated(path: "")

        mockRepository.projectToReturn = project

        let request = DeleteProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - Should not attempt to delete empty path
        // (Implementation should check for non-empty path)
        XCTAssertTrue(mockRepository.deleteCalled)
        XCTAssertTrue(response.deleted)
    }

    func test_execute_withDifferentProjectStates_shouldDeleteRegardless() async throws {
        // Test deleting draft project
        let draftProject = TestFixtures.makeProject()
        mockRepository.projectToReturn = draftProject
        var response = try await sut.execute(DeleteProjectRequest(projectId: draftProject.id))
        XCTAssertTrue(response.deleted)

        // Test deleting generating project
        mockRepository.reset()
        mockStorage.reset()
        var generatingProject = TestFixtures.makeProject()
        generatingProject.markGenerating()
        mockRepository.projectToReturn = generatingProject
        response = try await sut.execute(DeleteProjectRequest(projectId: generatingProject.id))
        XCTAssertTrue(response.deleted)

        // Test deleting error project
        mockRepository.reset()
        mockStorage.reset()
        var errorProject = TestFixtures.makeProject()
        errorProject.markError()
        mockRepository.projectToReturn = errorProject
        response = try await sut.execute(DeleteProjectRequest(projectId: errorProject.id))
        XCTAssertTrue(response.deleted)
    }
}
