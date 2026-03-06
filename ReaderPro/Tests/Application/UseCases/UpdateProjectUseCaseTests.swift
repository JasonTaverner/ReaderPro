import XCTest
@testable import ReaderPro

/// Tests para el Use Case UpdateProject
/// Actualiza nombre, texto y/o voz de un proyecto existente
final class UpdateProjectUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: UpdateProjectUseCase!
    var mockRepository: MockProjectRepositoryPort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        sut = UpdateProjectUseCase(projectRepository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Update Name Tests

    func test_execute_updateNameOnly_shouldUpdateName() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("Old Name"))
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "New Name",
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(response.name, "New Name")
        XCTAssertEqual(response.status, project.status)
    }

    func test_execute_updateNameOnly_shouldNotInvalidateAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(audioPath: "/audio/test.wav")
        let originalAudioPath = project.audioPath

        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "New Name",
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Audio should remain
        XCTAssertEqual(response.audioPath, originalAudioPath)
        XCTAssertEqual(response.status, .ready)
        XCTAssertTrue(response.hasAudio)
    }

    // MARK: - Update TextContent Tests

    func test_execute_updateTextOnly_shouldUpdateText() async throws {
        // Arrange
        let project = TestFixtures.makeProject(text: try! TextContent("Old text"))
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: "New text content",
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(response.text, "New text content")
    }

    func test_execute_updateText_shouldInvalidateAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(audioPath: "/audio/old.wav")
        XCTAssertNotNil(project.audioPath)
        XCTAssertEqual(project.status, .ready)

        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: "New text that invalidates audio",
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Audio should be invalidated
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.status, .draft)
        XCTAssertFalse(response.hasAudio)
    }

    // MARK: - Update Voice Tests

    func test_execute_updateVoiceConfiguration_shouldInvalidateAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: nil,
            voiceId: "new-voice",
            voiceName: "New Voice",
            voiceLanguage: "en-US",
            voiceProvider: .kokoro,
            speed: 1.5
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Audio should be invalidated
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.status, .draft)
        XCTAssertEqual(response.voiceId, "new-voice")
        XCTAssertEqual(response.voiceName, "New Voice")
        XCTAssertEqual(response.speed, 1.5)
    }

    func test_execute_updateOnlySpeed_shouldInvalidateAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: 1.8
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.status, .draft)
        XCTAssertEqual(response.speed, 1.8)
    }

    // MARK: - Multiple Updates Tests

    func test_execute_updateNameAndText_shouldInvalidateAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "New Name",
            text: "New text",
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.name, "New Name")
        XCTAssertEqual(response.text, "New text")
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.status, .draft)
    }

    func test_execute_updateAllFields_shouldUpdateAll() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "Updated Name",
            text: "Updated text",
            voiceId: "new-voice",
            voiceName: "New Voice Name",
            voiceLanguage: "fr-FR",
            voiceProvider: .qwen3,
            speed: 1.3
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - All fields updated
        XCTAssertEqual(response.name, "Updated Name")
        XCTAssertEqual(response.text, "Updated text")
        XCTAssertEqual(response.voiceId, "new-voice")
        XCTAssertEqual(response.voiceName, "New Voice Name")
        XCTAssertEqual(response.voiceLanguage, "fr-FR")
        XCTAssertEqual(response.voiceProvider, .qwen3)
        XCTAssertEqual(response.speed, 1.3)
    }

    func test_execute_noChanges_shouldNotModifyProject() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio()
        let originalAudioPath = project.audioPath

        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Nothing should change (but still saved for updatedAt)
        XCTAssertEqual(response.audioPath, originalAudioPath)
        XCTAssertEqual(response.status, .ready)
        XCTAssertTrue(mockRepository.saveCalled)
    }

    // MARK: - Validation Tests

    func test_execute_withInvalidText_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: "",  // Empty text
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for empty text")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_withInvalidName_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "",  // Empty name
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for empty name")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_withInvalidSpeed_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: nil,
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: 3.0  // Out of range
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for invalid speed")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    // MARK: - Error Tests

    func test_execute_withNonexistentProject_shouldThrowError() async {
        // Arrange
        mockRepository.projectToReturn = nil

        let request = UpdateProjectRequest(
            projectId: Identifier<Project>(),
            name: "New Name",
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

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
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_whenRepositoryThrows_shouldPropagateError() async {
        // Arrange
        struct RepositoryError: Error {}
        mockRepository.errorToThrow = RepositoryError()

        let request = UpdateProjectRequest(
            projectId: Identifier<Project>(),
            name: "New Name",
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }

    // MARK: - Timestamp Tests

    func test_execute_shouldUpdateTimestamp() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let originalUpdatedAt = project.updatedAt

        // Wait a bit to ensure time difference
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        mockRepository.projectToReturn = project

        let request = UpdateProjectRequest(
            projectId: project.id,
            name: "New Name",
            text: nil,
            voiceId: nil,
            voiceName: nil,
            voiceLanguage: nil,
            voiceProvider: nil,
            speed: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertGreaterThan(response.updatedAt, originalUpdatedAt)
    }

    // MARK: - Integration Tests

    func test_execute_fullUpdateFlow_shouldWork() async throws {
        // Arrange - Start with project with audio
        let originalProject = TestFixtures.makeProjectWithAudio(
            name: try! ProjectName("Original"),
            text: try! TextContent("Original text"),
            audioPath: "/audio/original.wav"
        )
        mockRepository.projectToReturn = originalProject

        // Act - Update everything
        let request = UpdateProjectRequest(
            projectId: originalProject.id,
            name: "Completely Updated",
            text: "Brand new text that invalidates audio",
            voiceId: "new-voice",
            voiceName: "New Voice",
            voiceLanguage: "en-GB",
            voiceProvider: .kokoro,
            speed: 1.4
        )

        let response = try await sut.execute(request)

        // Assert - Everything updated, audio invalidated
        XCTAssertEqual(response.projectId, originalProject.id)
        XCTAssertEqual(response.name, "Completely Updated")
        XCTAssertEqual(response.text, "Brand new text that invalidates audio")
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.status, .draft)
        XCTAssertEqual(response.voiceId, "new-voice")
        XCTAssertEqual(response.speed, 1.4)
        XCTAssertTrue(mockRepository.saveCalled)
    }
}
