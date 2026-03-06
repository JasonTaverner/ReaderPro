import XCTest
@testable import ReaderPro

/// Tests for ProcessTextBatchUseCase
@MainActor
final class ProcessTextBatchUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: ProcessTextBatchUseCase!
    var mockProjectRepository: MockProjectRepositoryPort!
    var mockSaveAudioEntryUseCase: MockSaveAudioEntryUseCase!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockProjectRepository = MockProjectRepositoryPort()
        mockSaveAudioEntryUseCase = MockSaveAudioEntryUseCase()

        sut = ProcessTextBatchUseCase(
            projectRepository: mockProjectRepository,
            saveAudioEntryUseCase: mockSaveAudioEntryUseCase
        )
    }

    override func tearDown() {
        sut = nil
        mockProjectRepository = nil
        mockSaveAudioEntryUseCase = nil
        super.tearDown()
    }

    // MARK: - Split by Paragraph Tests

    func test_execute_splitByParagraph_shouldCreateEntriesForEachParagraph() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = """
        First paragraph with some content.

        Second paragraph with more content.

        Third paragraph ending here.
        """

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 3)
        XCTAssertEqual(mockSaveAudioEntryUseCase.executeCallCount, 3)
    }

    func test_execute_splitByParagraph_withSingleParagraph_shouldCreateOneEntry() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = "This is a single paragraph without any line breaks."

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 1)
        XCTAssertEqual(mockSaveAudioEntryUseCase.executeCallCount, 1)
    }

    func test_execute_splitByParagraph_shouldIgnoreEmptyParagraphs() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = """
        First paragraph.



        Second paragraph.
        """

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 2)
    }

    // MARK: - Split by Sentence Tests

    func test_execute_splitBySentence_shouldCreateEntriesForEachSentence() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = "First sentence. Second sentence! Third sentence?"

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .sentence,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 3)
        XCTAssertEqual(mockSaveAudioEntryUseCase.executeCallCount, 3)
    }

    func test_execute_splitBySentence_shouldHandleAbbreviations() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        // "Dr." and "Mr." should not be split
        let text = "Dr. Smith visited Mr. Jones. They had a meeting."

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .sentence,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - Should be 2 sentences, not split at Dr. or Mr.
        XCTAssertEqual(response.entriesCreated, 2)
    }

    // MARK: - Split by Words Tests

    func test_execute_splitByWords_shouldCreateEntriesWithSpecifiedWordCount() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = "One two three four five six seven eight nine ten eleven twelve"

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .words(count: 5),
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - 12 words / 5 = 3 entries (5, 5, 2)
        XCTAssertEqual(response.entriesCreated, 3)
    }

    func test_execute_splitByWords_withExactMultiple_shouldNotCreateEmptyEntry() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = "One two three four five six seven eight nine ten"

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .words(count: 5),
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - 10 words / 5 = 2 entries exactly
        XCTAssertEqual(response.entriesCreated, 2)
    }

    func test_execute_splitByWords_withFewerWordsThanCount_shouldCreateOneEntry() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = "One two three"

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .words(count: 10),
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 1)
    }

    // MARK: - Error Cases

    func test_execute_withEmptyText_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: "",
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for empty text")
        } catch {
            XCTAssertTrue(error is ApplicationError)
        }
    }

    func test_execute_withWhitespaceOnlyText_shouldThrowError() async {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: "   \n\n   \t   ",
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for whitespace only text")
        } catch {
            XCTAssertTrue(error is ApplicationError)
        }
    }

    func test_execute_withNonexistentProject_shouldThrowError() async {
        // Arrange
        mockProjectRepository.projectToReturn = nil

        let request = ProcessTextBatchRequest(
            projectId: Identifier<Project>(),
            text: "Some text",
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw error for non-existent project")
        } catch {
            XCTAssertTrue(error is ApplicationError)
        }
    }

    // MARK: - Response Content Tests

    func test_execute_shouldReturnFragmentPreviews() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = """
        First paragraph with content.

        Second paragraph here.
        """

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: false
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.fragments.count, 2)
        XCTAssertTrue(response.fragments[0].contains("First"))
        XCTAssertTrue(response.fragments[1].contains("Second"))
    }

    // MARK: - Progress Callback Tests

    func test_execute_shouldCallProgressCallback() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let text = """
        First paragraph.

        Second paragraph.

        Third paragraph.
        """

        var progressUpdates: [(Int, Int)] = []
        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: false,
            onProgress: { current, total in
                progressUpdates.append((current, total))
            }
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(progressUpdates.count, 3)
        XCTAssertEqual(progressUpdates[0].0, 1)
        XCTAssertEqual(progressUpdates[0].1, 3)
        XCTAssertEqual(progressUpdates[1].0, 2)
        XCTAssertEqual(progressUpdates[1].1, 3)
        XCTAssertEqual(progressUpdates[2].0, 3)
        XCTAssertEqual(progressUpdates[2].1, 3)
    }

    // MARK: - Audio Generation Tests

    func test_execute_withGenerateAudioTrue_shouldCallTTSAndSaveAudio() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let projectId = project.id
        mockProjectRepository.projectToReturn = project

        let mockTTS = MockTTSPort()
        mockTTS.audioDataToReturn = TestFixtures.makeAudioData()
        
        sut = ProcessTextBatchUseCase(
            projectRepository: mockProjectRepository,
            ttsPort: mockTTS,
            saveAudioEntryUseCase: mockSaveAudioEntryUseCase
        )

        let text = "First paragraph.\n\nSecond paragraph."
        let voiceConfig = TestFixtures.makeVoiceConfiguration()
        let voice = TestFixtures.makeVoice()

        let request = ProcessTextBatchRequest(
            projectId: projectId,
            text: text,
            splitMode: .paragraph,
            generateAudio: true,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.entriesCreated, 2)
        XCTAssertEqual(response.entriesWithAudio, 2)
        XCTAssertEqual(mockTTS.synthesizeCallCount, 2)
        XCTAssertNotNil(mockSaveAudioEntryUseCase.lastRequest?.audioData)
    }
}
