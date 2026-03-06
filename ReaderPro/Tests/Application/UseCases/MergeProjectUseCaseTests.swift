import XCTest
@testable import ReaderPro

/// Tests para MergeProjectUseCase usando TDD
/// Flujo: Mergea entries de un proyecto → audio_completo.wav, documento.pdf, documento_completo.txt
@MainActor
final class MergeProjectUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: MergeProjectUseCase!
    var mockProjectRepository: MockProjectRepositoryPort!
    var mockAudioEditor: MockAudioEditorPort!
    var mockPDFGenerator: MockPDFGeneratorPort!
    var mockFileStorage: MockFileStoragePort!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockProjectRepository = MockProjectRepositoryPort()
        mockAudioEditor = MockAudioEditorPort()
        mockPDFGenerator = MockPDFGeneratorPort()
        mockFileStorage = MockFileStoragePort()

        sut = MergeProjectUseCase(
            projectRepository: mockProjectRepository,
            audioEditor: mockAudioEditor,
            pdfGenerator: mockPDFGenerator,
            fileStorage: mockFileStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockProjectRepository = nil
        mockAudioEditor = nil
        mockPDFGenerator = nil
        mockFileStorage = nil
        super.tearDown()
    }

    // MARK: - Project Validation Tests

    func test_execute_withNonexistentProject_shouldThrowProjectNotFound() async {
        // Arrange
        let projectId = Identifier<Project>()
        mockProjectRepository.projectToReturn = nil
        let request = MergeProjectRequest(projectId: projectId, mergeType: .all)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw projectNotFound")
        } catch {
            XCTAssertEqual(error as? ApplicationError, .projectNotFound)
        }
    }

    func test_execute_withEmptyProject_shouldThrowNoEntriesToMerge() async throws {
        // Arrange
        let project = try makeEmptyProject()
        mockProjectRepository.projectToReturn = project
        let request = MergeProjectRequest(projectId: project.id, mergeType: .all)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw noEntriesToMerge")
        } catch {
            XCTAssertEqual(error as? ApplicationError, .noEntriesToMerge)
        }
    }

    // MARK: - Audio Merge Tests

    func test_execute_withAudioMergeType_shouldCallConcatenate() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 3)
        mockProjectRepository.projectToReturn = project
        mockAudioEditor.concatenateResult = "/exports/audio_completo.wav"

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockAudioEditor.concatenateCallCount, 1)
    }

    func test_execute_withAudioMergeType_shouldPassCorrectAudioPaths() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 3)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        _ = try await sut.execute(request)

        // Assert
        let expectedPaths = project.entries.compactMap { $0.audioPath }
        XCTAssertEqual(mockAudioEditor.lastConcatenateAudioPaths, expectedPaths)
    }

    func test_execute_withAudioMergeType_shouldUseSilenceDuration() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(
            projectId: project.id,
            mergeType: .audio,
            silenceBetweenAudios: 1.5
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockAudioEditor.lastConcatenateSilenceDuration, 1.5)
    }

    func test_execute_withAudioMergeType_shouldUseDefaultSilenceOf05Seconds() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockAudioEditor.lastConcatenateSilenceDuration, 0.5)
    }

    func test_execute_withAudioMergeType_shouldReturnMergedAudioPath() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project
        mockAudioEditor.concatenateResult = "/project/exports/audio_completo.wav"

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.mergedAudioPath, "/project/exports/audio_completo.wav")
        XCTAssertNil(response.mergedPDFPath)
        XCTAssertNil(response.mergedTextPath)
    }

    func test_execute_withAudioMergeType_shouldSkipEntriesWithoutAudio() async throws {
        // Arrange
        let project = try makeProjectWithMixedEntries()
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        _ = try await sut.execute(request)

        // Assert
        let expectedPaths = project.entries.compactMap { $0.audioPath }
        XCTAssertEqual(mockAudioEditor.lastConcatenateAudioPaths?.count, expectedPaths.count)
    }

    func test_execute_withAudioMergeType_noAudioEntries_shouldNotCallConcatenate() async throws {
        // Arrange
        let project = try makeProjectWithEntriesNoAudio()
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockAudioEditor.concatenateCallCount, 0)
        XCTAssertNil(response.mergedAudioPath)
    }

    // MARK: - Image Merge (PDF) Tests

    func test_execute_withImagesMergeType_shouldCallGeneratePDF() async throws {
        // Arrange
        let project = try makeProjectWithEntries(imageCount: 3)
        mockProjectRepository.projectToReturn = project
        mockPDFGenerator.generatePDFResult = "/exports/documento.pdf"

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockPDFGenerator.generatePDFCallCount, 1)
    }

    func test_execute_withImagesMergeType_shouldPassCorrectImagePaths() async throws {
        // Arrange
        let project = try makeProjectWithEntries(imageCount: 3)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act
        _ = try await sut.execute(request)

        // Assert
        let expectedPaths = project.entries.compactMap { $0.imagePath }
        XCTAssertEqual(mockPDFGenerator.lastImagePaths, expectedPaths)
    }

    func test_execute_withImagesMergeType_shouldReturnMergedPDFPath() async throws {
        // Arrange
        let project = try makeProjectWithEntries(imageCount: 2)
        mockProjectRepository.projectToReturn = project
        mockPDFGenerator.generatePDFResult = "/project/exports/documento.pdf"

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.mergedPDFPath, "/project/exports/documento.pdf")
        XCTAssertNil(response.mergedAudioPath)
        XCTAssertNil(response.mergedTextPath)
    }

    func test_execute_withImagesMergeType_noImageEntries_shouldNotCallGeneratePDF() async throws {
        // Arrange
        let project = try makeProjectWithEntriesNoImages()
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockPDFGenerator.generatePDFCallCount, 0)
        XCTAssertNil(response.mergedPDFPath)
    }

    // MARK: - Text Merge Tests

    func test_execute_withTextMergeType_shouldSaveConcatenatedText() async throws {
        // Arrange
        let project = try makeProjectWithEntries(count: 3)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .text)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockFileStorage.saveTextCalled)
    }

    func test_execute_withTextMergeType_shouldConcatenateAllTexts() async throws {
        // Arrange
        let project = try makeProjectWithEntries(count: 3)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .text)

        // Act
        _ = try await sut.execute(request)

        // Assert
        let savedText = mockFileStorage.lastSavedText ?? ""
        // Each entry has "Test entry X" text
        XCTAssertTrue(savedText.contains("Test entry 1"))
        XCTAssertTrue(savedText.contains("Test entry 2"))
        XCTAssertTrue(savedText.contains("Test entry 3"))
    }

    func test_execute_withTextMergeType_shouldSaveToCorrectPath() async throws {
        // Arrange
        let project = try makeProjectWithEntries(count: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .text)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockFileStorage.lastSavedTextPath?.contains("documento_completo.txt") ?? false)
    }

    func test_execute_withTextMergeType_shouldReturnMergedTextPath() async throws {
        // Arrange
        let project = try makeProjectWithEntries(count: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .text)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertNotNil(response.mergedTextPath)
        XCTAssertNil(response.mergedAudioPath)
        XCTAssertNil(response.mergedPDFPath)
    }

    // MARK: - All Merge Tests

    func test_execute_withAllMergeType_shouldMergeAudioImagesAndText() async throws {
        // Arrange
        let project = try makeProjectWithFullEntries(count: 3)
        mockProjectRepository.projectToReturn = project
        mockAudioEditor.concatenateResult = "/exports/audio_completo.wav"
        mockPDFGenerator.generatePDFResult = "/exports/documento.pdf"

        let request = MergeProjectRequest(projectId: project.id, mergeType: .all)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(mockAudioEditor.concatenateCallCount, 1)
        XCTAssertEqual(mockPDFGenerator.generatePDFCallCount, 1)
        XCTAssertTrue(mockFileStorage.saveTextCalled)
        XCTAssertNotNil(response.mergedAudioPath)
        XCTAssertNotNil(response.mergedPDFPath)
        XCTAssertNotNil(response.mergedTextPath)
    }

    // MARK: - Exports Directory Tests

    func test_execute_shouldSaveToExportsDirectory() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(response.exportsDirectory.contains("exports"))
    }

    func test_execute_shouldCreateExportsDirectoryIfNeeded() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockFileStorage.createDirectoryCalled)
    }

    // MARK: - Response Metadata Tests

    func test_execute_shouldReturnProjectMetadata() async throws {
        // Arrange
        let project = try makeProjectWithEntries(count: 5)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .text)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.projectId, project.id)
        XCTAssertEqual(response.projectName, project.name.value)
        XCTAssertEqual(response.entriesProcessed, 5)
    }

    func test_execute_withImagesMerge_shouldReturnPDFPageCount() async throws {
        // Arrange
        let project = try makeProjectWithEntries(imageCount: 4)
        mockProjectRepository.projectToReturn = project

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.pdfPageCount, 4)
    }

    // MARK: - Error Handling Tests

    func test_execute_whenAudioEditorFails_shouldPropagateError() async throws {
        // Arrange
        let project = try makeProjectWithEntries(audioCount: 2)
        mockProjectRepository.projectToReturn = project
        mockAudioEditor.errorToThrow = NSError(domain: "Audio", code: 1, userInfo: nil)

        let request = MergeProjectRequest(projectId: project.id, mergeType: .audio)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_execute_whenPDFGeneratorFails_shouldPropagateError() async throws {
        // Arrange
        let project = try makeProjectWithEntries(imageCount: 2)
        mockProjectRepository.projectToReturn = project
        mockPDFGenerator.errorToThrow = NSError(domain: "PDF", code: 1, userInfo: nil)

        let request = MergeProjectRequest(projectId: project.id, mergeType: .images)

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Test Helpers

    private func makeEmptyProject() throws -> Project {
        let name = try ProjectName("Test Project")
        let voice = Voice(
            id: "test-voice",
            name: "Test Voice",
            language: "es-ES",
            provider: .native,
            isDefault: true
        )
        let config = VoiceConfiguration(
            voiceId: "test-voice",
            speed: try VoiceConfiguration.Speed(1.0)
        )
        return Project(name: name, voiceConfiguration: config, voice: voice)
    }

    private func makeProjectWithEntries(count: Int = 3, audioCount: Int = 0, imageCount: Int = 0) throws -> Project {
        let project = try makeEmptyProject()
        for i in 1...count {
            let text = try TextContent("Test entry \(i)")
            var entry = AudioEntry(text: text)
            if i <= audioCount {
                entry.setAudioPath("/audio/\(i).wav")
            }
            if i <= imageCount {
                entry.setImagePath("/images/\(i).png")
            }
            try project.addEntry(entry)
        }
        return project
    }

    private func makeProjectWithFullEntries(count: Int) throws -> Project {
        let project = try makeEmptyProject()
        for i in 1...count {
            let text = try TextContent("Full entry \(i)")
            var entry = AudioEntry(text: text)
            entry.setAudioPath("/audio/\(i).wav")
            entry.setImagePath("/images/\(i).png")
            try project.addEntry(entry)
        }
        return project
    }

    private func makeProjectWithMixedEntries() throws -> Project {
        let project = try makeEmptyProject()
        // Entry 1: has audio
        let text1 = try TextContent("Entry with audio")
        var entry1 = AudioEntry(text: text1)
        entry1.setAudioPath("/audio/1.wav")
        try project.addEntry(entry1)

        // Entry 2: no audio
        let text2 = try TextContent("Entry without audio")
        let entry2 = AudioEntry(text: text2)
        try project.addEntry(entry2)

        // Entry 3: has audio
        let text3 = try TextContent("Another entry with audio")
        var entry3 = AudioEntry(text: text3)
        entry3.setAudioPath("/audio/3.wav")
        try project.addEntry(entry3)

        return project
    }

    private func makeProjectWithEntriesNoAudio() throws -> Project {
        let project = try makeEmptyProject()
        for i in 1...3 {
            let text = try TextContent("Entry \(i) no audio")
            let entry = AudioEntry(text: text)
            try project.addEntry(entry)
        }
        return project
    }

    private func makeProjectWithEntriesNoImages() throws -> Project {
        let project = try makeEmptyProject()
        for i in 1...3 {
            let text = try TextContent("Entry \(i) no image")
            var entry = AudioEntry(text: text)
            entry.setAudioPath("/audio/\(i).wav")
            try project.addEntry(entry)
        }
        return project
    }
}
