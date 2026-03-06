import XCTest
@testable import ReaderPro

/// Tests para el Use Case CreateProject
/// Crea un nuevo proyecto y lo persiste
final class CreateProjectUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: CreateProjectUseCase!
    var mockRepository: MockProjectRepositoryPort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        sut = CreateProjectUseCase(projectRepository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func test_execute_withValidRequest_shouldCreateAndSaveProject() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Este es el texto del proyecto",
            name: "Mi Proyecto",
            voiceId: "voice-1",
            voiceName: "Spanish Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
        XCTAssertNotNil(mockRepository.lastSavedProject)

        let savedProject = mockRepository.lastSavedProject!
        XCTAssertEqual(savedProject.name.value, "Mi Proyecto")
        XCTAssertEqual(savedProject.text?.value, "Este es el texto del proyecto")
        XCTAssertEqual(savedProject.voiceConfiguration.voiceId, "voice-1")
        XCTAssertEqual(savedProject.voice.id, "voice-1")
        XCTAssertEqual(savedProject.voice.name, "Spanish Voice")
        XCTAssertEqual(savedProject.status, .draft)

        // Response validation
        XCTAssertEqual(response.projectId, savedProject.id)
        XCTAssertEqual(response.projectName, "Mi Proyecto")
        XCTAssertEqual(response.status, .draft)
    }

    func test_execute_withoutNameProvided_shouldGenerateNameFromText() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Este es un texto largo que debería ser truncado para el nombre automático",
            name: nil,  // No name provided
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.saveCalled)
        let savedProject = mockRepository.lastSavedProject!

        // Should generate name from text (truncated and cleaned)
        XCTAssertFalse(savedProject.name.value.isEmpty)
        XCTAssertLessThanOrEqual(savedProject.name.value.count, 50)
        XCTAssertEqual(response.projectName, savedProject.name.value)
    }

    func test_execute_withCustomVoiceConfiguration_shouldUseProvidedValues() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "custom-voice",
            voiceName: "Custom",
            voiceLanguage: "en-US",
            voiceProvider: .kokoro,
            speed: 1.5
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertEqual(savedProject.voiceConfiguration.speed.value, 1.5)
        XCTAssertEqual(savedProject.voice.provider, .kokoro)
    }

    func test_execute_withDefaultSpeed_shouldUseNormalSpeed() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: nil  // Not provided
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertEqual(savedProject.voiceConfiguration.speed.value, 1.0)
    }

    func test_execute_shouldGenerateUniqueProjectId() async throws {
        // Arrange
        let request1 = CreateProjectRequest(
            text: "Texto 1",
            name: "Proyecto 1",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        let request2 = CreateProjectRequest(
            text: "Texto 2",
            name: "Proyecto 2",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act
        let response1 = try await sut.execute(request1)
        mockRepository.reset()
        let response2 = try await sut.execute(request2)

        // Assert
        XCTAssertNotEqual(response1.projectId, response2.projectId)
    }

    func test_execute_shouldSetCreatedAtTimestamp() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )
        let before = Date()

        // Act
        let response = try await sut.execute(request)

        let after = Date()

        // Assert
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertGreaterThanOrEqual(savedProject.createdAt, before)
        XCTAssertLessThanOrEqual(savedProject.createdAt, after)
        XCTAssertNotNil(response.createdAt)
    }

    // MARK: - Validation Tests

    func test_execute_withEmptyText_shouldCreateProjectWithNilText() async throws {
        // Arrange - empty text is now valid, creates project with nil text
        let request = CreateProjectRequest(
            text: "",  // Empty text
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - project created with nil text
        XCTAssertTrue(mockRepository.saveCalled)
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertNil(savedProject.text)
        XCTAssertEqual(savedProject.name.value, "Proyecto")
        XCTAssertNotNil(response.projectId)
    }

    func test_execute_withWhitespaceOnlyText_shouldThrowError() async {
        // Arrange
        let request = CreateProjectRequest(
            text: "   \n\t  ",  // Whitespace only
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for whitespace-only text")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_withTextExceedingLimit_shouldThrowError() async {
        // Arrange
        let longText = String(repeating: "a", count: 6001)  // Exceeds 6000 char limit
        let request = CreateProjectRequest(
            text: longText,
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for text exceeding limit")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_withInvalidSpeed_shouldThrowError() async {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 3.0  // Invalid (out of 0.5-2.0 range)
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

    func test_execute_withEmptyProjectName_shouldThrowError() async {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto válido",
            name: "",  // Empty name
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for empty project name")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_withNameExceedingLimit_shouldThrowError() async {
        // Arrange
        let longName = String(repeating: "a", count: 101)  // Exceeds 100 char limit
        let request = CreateProjectRequest(
            text: "Texto",
            name: longName,
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for name exceeding limit")
        } catch {
            XCTAssertTrue(error is DomainError)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    // MARK: - Repository Error Tests

    func test_execute_whenRepositoryThrows_shouldPropagateError() async {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        struct RepositoryError: Error {}
        mockRepository.errorToThrow = RepositoryError()

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            XCTAssertTrue(mockRepository.saveCalled)
        }
    }

    // MARK: - Domain Events Tests

    func test_execute_shouldEmitProjectCreatedEvent() async throws {
        // Arrange
        let request = CreateProjectRequest(
            text: "Texto",
            name: "Proyecto",
            voiceId: "voice-1",
            voiceName: "Voice",
            voiceLanguage: "es-ES",
            voiceProvider: .native,
            speed: 1.0
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertEqual(savedProject.domainEvents.count, 1)
        XCTAssertTrue(savedProject.domainEvents.first is ProjectCreatedEvent)
    }
}
