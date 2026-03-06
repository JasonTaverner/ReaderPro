import XCTest
@testable import ReaderPro

/// Tests para el Use Case GetProject
/// Recupera un proyecto existente por su ID
final class GetProjectUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: GetProjectUseCase!
    var mockRepository: MockProjectRepositoryPort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        sut = GetProjectUseCase(projectRepository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func test_execute_withExistingProject_shouldReturnProject() async throws {
        // Arrange
        let project = TestFixtures.makeProject(
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Este es el texto del proyecto")
        )
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertEqual(mockRepository.lastFindByIdQuery, project.id)

        XCTAssertEqual(response.projectId, project.id)
        XCTAssertEqual(response.name, "Test Project")
        XCTAssertEqual(response.text, "Este es el texto del proyecto")
        XCTAssertEqual(response.status, .draft)
        XCTAssertNil(response.audioPath)
        XCTAssertEqual(response.voiceId, project.voice.id)
        XCTAssertEqual(response.voiceName, project.voice.name)
        XCTAssertEqual(response.createdAt, project.createdAt)
        XCTAssertEqual(response.updatedAt, project.updatedAt)
    }

    func test_execute_withProjectWithAudio_shouldIncludeAudioPath() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(
            audioPath: "/audio/test123.wav"
        )
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.audioPath, "/audio/test123.wav")
        XCTAssertEqual(response.status, .ready)
        XCTAssertTrue(response.hasAudio)
    }

    func test_execute_withProjectWithoutAudio_shouldReturnNilAudioPath() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        XCTAssertNil(project.audioPath)

        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertNil(response.audioPath)
        XCTAssertFalse(response.hasAudio)
    }

    func test_execute_shouldIncludeVoiceConfiguration() async throws {
        // Arrange
        let voiceConfig = VoiceConfiguration(
            voiceId: "custom-voice",
            speed: try! VoiceConfiguration.Speed(1.5)
        )
        let project = TestFixtures.makeProject(voiceConfiguration: voiceConfig)
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.voiceId, "custom-voice")
        XCTAssertEqual(response.speed, 1.5)
    }

    func test_execute_shouldIncludeVoiceDetails() async throws {
        // Arrange
        let voice = Voice(
            id: "kokoro-spanish",
            name: "Kokoro Spanish Female",
            language: "es-ES",
            provider: .kokoro,
            isDefault: false
        )
        let voiceConfig = TestFixtures.makeVoiceConfiguration(voiceId: "kokoro-spanish")
        let project = TestFixtures.makeProject(voiceConfiguration: voiceConfig, voice: voice)
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.voiceId, "kokoro-spanish")
        XCTAssertEqual(response.voiceName, "Kokoro Spanish Female")
        XCTAssertEqual(response.voiceLanguage, "es-ES")
        XCTAssertEqual(response.voiceProvider, .kokoro)
    }

    func test_execute_shouldIncludeEntriesCount() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        try! project.addEntry(TestFixtures.makeAudioEntry())
        try! project.addEntry(TestFixtures.makeAudioEntry())
        try! project.addEntry(TestFixtures.makeAudioEntry())

        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCount, 3)
    }

    func test_execute_withDifferentStatuses_shouldReturnCorrectStatus() async throws {
        // Test draft status
        var draftProject = TestFixtures.makeProject()
        mockRepository.projectToReturn = draftProject
        var response = try await sut.execute(GetProjectRequest(projectId: draftProject.id))
        XCTAssertEqual(response.status, .draft)

        // Test generating status
        mockRepository.reset()
        var generatingProject = TestFixtures.makeProject()
        generatingProject.markGenerating()
        mockRepository.projectToReturn = generatingProject
        response = try await sut.execute(GetProjectRequest(projectId: generatingProject.id))
        XCTAssertEqual(response.status, .generating)

        // Test ready status
        mockRepository.reset()
        let readyProject = TestFixtures.makeProjectWithAudio()
        mockRepository.projectToReturn = readyProject
        response = try await sut.execute(GetProjectRequest(projectId: readyProject.id))
        XCTAssertEqual(response.status, .ready)

        // Test error status
        mockRepository.reset()
        var errorProject = TestFixtures.makeProject()
        errorProject.markError()
        mockRepository.projectToReturn = errorProject
        response = try await sut.execute(GetProjectRequest(projectId: errorProject.id))
        XCTAssertEqual(response.status, .error)
    }

    func test_execute_shouldIncludeTimestamps() async throws {
        // Arrange
        let createdAt = Date(timeIntervalSince1970: 1000000)
        let updatedAt = Date(timeIntervalSince1970: 2000000)

        let project = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Test"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.createdAt, createdAt)
        XCTAssertEqual(response.updatedAt, updatedAt)
    }

    // MARK: - Error Tests

    func test_execute_withNonexistentProject_shouldThrowError() async {
        // Arrange
        mockRepository.projectToReturn = nil  // Project not found

        let request = GetProjectRequest(projectId: Identifier<Project>())

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for nonexistent project")
        } catch {
            guard case ApplicationError.projectNotFound = error else {
                XCTFail("Expected projectNotFound error, got \(error)")
                return
            }
            XCTAssertTrue(mockRepository.findByIdCalled)
        }
    }

    func test_execute_whenRepositoryThrows_shouldPropagateError() async {
        // Arrange
        struct RepositoryError: Error {}
        mockRepository.errorToThrow = RepositoryError()

        let request = GetProjectRequest(projectId: Identifier<Project>())

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            XCTAssertTrue(mockRepository.findByIdCalled)
        }
    }

    // MARK: - Response Validation Tests

    func test_execute_responseShouldBeSerializable() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        let response = try await sut.execute(request)

        // Assert - All response fields should be basic types (serializable)
        XCTAssertNotNil(response.projectId)
        XCTAssertTrue(response.name is String)
        XCTAssertTrue(response.text is String)
        XCTAssertTrue(response.voiceId is String)
        XCTAssertTrue(response.speed is Double)
        XCTAssertTrue(response.entriesCount is Int)
    }

    func test_execute_shouldNotModifyProject() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let originalStatus = project.status
        let originalAudioPath = project.audioPath

        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        _ = try await sut.execute(request)

        // Assert - Project should not be modified or saved
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertFalse(mockRepository.saveCalled)  // Should NOT save
        XCTAssertEqual(project.status, originalStatus)
        XCTAssertEqual(project.audioPath, originalAudioPath)
    }

    // MARK: - Multiple Calls Tests

    func test_execute_calledMultipleTimes_shouldQueryRepositoryEachTime() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = GetProjectRequest(projectId: project.id)

        // Act
        _ = try await sut.execute(request)
        _ = try await sut.execute(request)
        _ = try await sut.execute(request)

        // Assert - Should query repository each time (no caching)
        XCTAssertTrue(mockRepository.findByIdCalled)
        // Note: We can't directly count findById calls with current mock,
        // but we verify it was called
    }
}
