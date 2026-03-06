import XCTest
@testable import ReaderPro

/// Tests para el Use Case SaveAudioEntry
/// Guarda una entrada de audio/texto resultado de OCR + TTS
final class SaveAudioEntryUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: SaveAudioEntryUseCase!
    var mockRepository: MockProjectRepositoryPort!
    var mockAudioStorage: MockAudioStoragePort!
    var mockFileStorage: MockFileStoragePort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        mockAudioStorage = MockAudioStoragePort()
        mockFileStorage = MockFileStoragePort()

        sut = SaveAudioEntryUseCase(
            projectRepository: mockRepository,
            audioStorage: mockAudioStorage,
            fileStorage: mockFileStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockAudioStorage = nil
        mockFileStorage = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func test_execute_withFirstEntry_shouldCreateEntry001() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        XCTAssertEqual(project.entries.count, 0)

        mockRepository.projectToReturn = project
        mockFileStorage.pathToGenerate = "/path/001.txt"
        mockAudioStorage.pathToReturn = "/path/001.wav"

        let audioData = Data(repeating: 1, count: 1024)
        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto reconocido por OCR",
            audioData: audioData,
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Repository operations
        XCTAssertTrue(mockRepository.findByIdCalled)
        XCTAssertTrue(mockRepository.saveCalled)

        // Assert - Entry number
        XCTAssertEqual(response.entryNumber, 1)
        XCTAssertTrue(response.entryId.contains("001"))

        // Assert - File storage operations
        XCTAssertTrue(mockFileStorage.saveTextCalled)
        XCTAssertEqual(mockFileStorage.lastSavedText, "Texto reconocido por OCR")

        // Assert - Audio storage
        XCTAssertTrue(mockAudioStorage.saveCalled)
        XCTAssertEqual(mockAudioStorage.lastSavedAudioData?.data, audioData)

        // Assert - Response
        XCTAssertNotNil(response.textPath)
        XCTAssertNotNil(response.audioPath)
        XCTAssertNil(response.imagePath)
    }

    func test_execute_withSecondEntry_shouldCreateEntry002() async throws {
        // Arrange
        var project = TestFixtures.makeProject()

        // Add first entry
        let entry1 = TestFixtures.makeAudioEntry()
        try! project.addEntry(entry1)
        XCTAssertEqual(project.entries.count, 1)

        mockRepository.projectToReturn = project
        mockFileStorage.pathToGenerate = "/path/002.txt"
        mockAudioStorage.pathToReturn = "/path/002.wav"

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Segunda entrada",
            audioData: Data(repeating: 2, count: 512),
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entryNumber, 2)
        XCTAssertTrue(response.entryId.contains("002"))
    }

    func test_execute_withThirdEntry_shouldCreateEntry003() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        try! project.addEntry(TestFixtures.makeAudioEntry())
        try! project.addEntry(TestFixtures.makeAudioEntry())
        XCTAssertEqual(project.entries.count, 2)

        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Tercera entrada",
            audioData: Data(repeating: 3, count: 512),
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entryNumber, 3)
        XCTAssertTrue(response.entryId.contains("003"))
    }

    func test_execute_withImagePath_shouldPersistImage() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project
        // El mock devolverá este path para ambas llamadas (texto e imagen)
        // pero la verificación se hace sobre los parámetros del mock
        mockFileStorage.pathToGenerate = "\(project.folderName!)/001.png"
        mockAudioStorage.pathToReturn = "/path/001.wav"

        // Crear un archivo temporal real para que SaveAudioEntryUseCase pueda leerlo
        let tempDir = FileManager.default.temporaryDirectory
        let tempImagePath = tempDir.appendingPathComponent("test_capture_\(UUID().uuidString).png").path
        let imageData = Data(repeating: 255, count: 2048)
        FileManager.default.createFile(atPath: tempImagePath, contents: imageData)
        defer { try? FileManager.default.removeItem(atPath: tempImagePath) }

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto con imagen",
            audioData: Data(repeating: 1, count: 1024),
            imagePath: tempImagePath
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Image was copied to fileStorage
        XCTAssertTrue(mockFileStorage.saveCalled)
        XCTAssertNotNil(mockFileStorage.lastSavedData)
        XCTAssertEqual(mockFileStorage.lastSavedData, imageData)

        // Assert - generateNumberedPath was called with correct parameters for image
        // (project folder name as base directory, number 1, and png extension)
        XCTAssertTrue(mockFileStorage.generateNumberedPathCalled)
        XCTAssertEqual(mockFileStorage.lastGeneratedBaseDirectory, project.folderName)
        XCTAssertEqual(mockFileStorage.lastGeneratedExtension, "png")

        // Assert - Response contains the saved path
        XCTAssertNotNil(response.imagePath)
    }

    func test_execute_withoutImagePath_shouldNotSaveImage() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto sin imagen",
            audioData: Data(repeating: 1, count: 1024),
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - No image data saved to fileStorage
        XCTAssertNil(response.imagePath)
        XCTAssertFalse(mockFileStorage.saveCalled)
    }

    func test_execute_shouldGenerateCorrectPaths() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        mockFileStorage.pathToGenerate = "/Documents/KokoroLibrary/001.txt"
        mockAudioStorage.pathToReturn = "/Documents/KokoroLibrary/001.wav"

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(response.textPath.contains("001"))
        XCTAssertTrue(response.audioPath.contains("001"))
    }

    func test_execute_shouldAddEntryToProject() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        let initialCount = project.entries.count
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Nueva entrada",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act
        _ = try await sut.execute(request)

        // Assert - Project should have one more entry
        let savedProject = mockRepository.lastSavedProject!
        XCTAssertEqual(savedProject.entries.count, initialCount + 1)
    }

    func test_execute_shouldSaveProjectAfterAddingEntry() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertNotNil(mockRepository.lastSavedProject)
    }

    func test_execute_shouldCreateAudioDataFromBytes() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let audioBytes = Data(repeating: 42, count: 2048)
        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: audioBytes,
            imagePath: nil
        )

        // Act
        _ = try await sut.execute(request)

        // Assert - Audio storage should receive the data
        XCTAssertTrue(mockAudioStorage.saveCalled)
        XCTAssertEqual(mockAudioStorage.lastSavedAudioData?.data, audioBytes)
    }

    // MARK: - Validation Tests

    func test_execute_withEmptyText_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "",  // Empty text
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
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

    func test_execute_withWhitespaceOnlyText_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "   \n\t  ",  // Whitespace only
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for whitespace-only text")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    func test_execute_withEmptyAudioData_shouldSaveTextOnly() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto válido",
            audioData: Data(),  // Empty audio - should skip audio saving
            imagePath: nil
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - entry saved with text but no audio
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(response.entryNumber, 1)
    }

    func test_execute_withNilAudioData_shouldSaveTextOnly() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        // Crear un archivo temporal real para la imagen
        let tempDir = FileManager.default.temporaryDirectory
        let tempImagePath = tempDir.appendingPathComponent("test_screenshot_\(UUID().uuidString).png").path
        FileManager.default.createFile(atPath: tempImagePath, contents: Data(repeating: 1, count: 64))
        defer { try? FileManager.default.removeItem(atPath: tempImagePath) }

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto sin audio",
            audioData: nil,
            imagePath: tempImagePath
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - entry saved without audio but with image
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(response.entryNumber, 1)
        XCTAssertFalse(mockAudioStorage.saveCalled)
        XCTAssertTrue(mockFileStorage.saveCalled)  // Image was saved
        XCTAssertNotNil(response.imagePath)
    }

    // MARK: - Error Tests

    func test_execute_withNonexistentProject_shouldThrowError() async {
        // Arrange
        mockRepository.projectToReturn = nil

        let request = SaveAudioEntryRequest(
            projectId: Identifier<Project>(),
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
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
            XCTAssertFalse(mockFileStorage.saveTextCalled)
        }
    }

    func test_execute_whenTextSaveFails_shouldPropagateError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        struct StorageError: Error {}
        mockFileStorage.errorToThrow = StorageError()

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate storage error")
        } catch {
            XCTAssertTrue(error is StorageError)
            XCTAssertTrue(mockFileStorage.saveTextCalled)
            XCTAssertFalse(mockRepository.saveCalled)
        }
    }

    func test_execute_whenAudioSaveFails_shouldPropagateError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        struct StorageError: Error {}
        mockAudioStorage.errorToThrow = StorageError()

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate audio storage error")
        } catch {
            XCTAssertTrue(error is StorageError)
            XCTAssertTrue(mockAudioStorage.saveCalled)
        }
    }

    func test_execute_whenRepositorySaveFails_shouldPropagateError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        struct RepositoryError: Error {}
        mockRepository.saveErrorToThrow = RepositoryError()  // Use save-specific error

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            XCTAssertTrue(mockRepository.saveCalled)
        }
    }

    // MARK: - Integration Tests

    func test_execute_fullFlow_shouldCoordinateAllOperations() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        // El mock devuelve el mismo path para todas las llamadas a generateNumberedPath
        // pero verificamos que se llama con los parámetros correctos
        mockFileStorage.pathToGenerate = "\(project.folderName!)/001.png"
        mockAudioStorage.pathToReturn = "/Documents/KokoroLibrary/001.wav"

        // Crear un archivo temporal real para la imagen
        let tempDir = FileManager.default.temporaryDirectory
        let tempImagePath = tempDir.appendingPathComponent("test_capture_\(UUID().uuidString).png").path
        let imageData = Data(repeating: 200, count: 1024)
        FileManager.default.createFile(atPath: tempImagePath, contents: imageData)
        defer { try? FileManager.default.removeItem(atPath: tempImagePath) }

        let request = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Texto reconocido por OCR",
            audioData: Data(repeating: 42, count: 2048),
            imagePath: tempImagePath
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - All operations executed
        XCTAssertTrue(mockRepository.findByIdCalled)      // 1. Find project
        XCTAssertTrue(mockFileStorage.saveTextCalled)     // 2. Save text
        XCTAssertTrue(mockAudioStorage.saveCalled)        // 3. Save audio
        XCTAssertTrue(mockFileStorage.saveCalled)         // 4. Save image
        XCTAssertTrue(mockRepository.saveCalled)          // 5. Save project

        // Assert - generateNumberedPath was called with project folder name as base directory
        XCTAssertTrue(mockFileStorage.generateNumberedPathCalled)
        XCTAssertEqual(mockFileStorage.lastGeneratedBaseDirectory, project.folderName)

        // Assert - Response complete
        XCTAssertEqual(response.entryNumber, 1)
        XCTAssertNotNil(response.imagePath)
    }

    func test_execute_multipleEntries_shouldIncrementNumbers() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        mockRepository.projectToReturn = project

        // Act - Save first entry
        mockFileStorage.pathToGenerate = "/path/001.txt"
        mockAudioStorage.pathToReturn = "/path/001.wav"
        let request1 = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Primera entrada",
            audioData: Data(repeating: 1, count: 512),
            imagePath: nil
        )
        let response1 = try await sut.execute(request1)

        // Note: use case already added entry to project (Project is a class/reference type)
        // So project now has 1 entry, no need to manually add another
        mockRepository.reset()
        mockRepository.projectToReturn = project  // Project already has 1 entry from first execute

        // Act - Save second entry
        mockFileStorage.reset()
        mockAudioStorage.reset()
        mockFileStorage.pathToGenerate = "/path/002.txt"
        mockAudioStorage.pathToReturn = "/path/002.wav"
        let request2 = SaveAudioEntryRequest(
            projectId: project.id,
            text: "Segunda entrada",
            audioData: Data(repeating: 2, count: 512),
            imagePath: nil
        )
        let response2 = try await sut.execute(request2)

        // Assert
        XCTAssertEqual(response1.entryNumber, 1)
        XCTAssertEqual(response2.entryNumber, 2)
    }
}
