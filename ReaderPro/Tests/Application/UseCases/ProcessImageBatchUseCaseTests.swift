import XCTest
@testable import ReaderPro

/// Tests para ProcessImageBatchUseCase usando TDD
final class ProcessImageBatchUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: ProcessImageBatchUseCase!
    var mockOCR: MockOCRPort!
    var mockSaveAudioEntry: MockSaveAudioEntryUseCase!
    var tempDir: URL!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockOCR = MockOCRPort()
        mockSaveAudioEntry = await MockSaveAudioEntryUseCase()

        sut = ProcessImageBatchUseCase(
            ocrPort: mockOCR,
            saveAudioEntryUseCase: mockSaveAudioEntry
        )

        // Create a writable temp directory for test files
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProcessImageBatchTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        sut = nil
        mockOCR = nil
        mockSaveAudioEntry = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withEmptyURLs_shouldReturnEmptyResponse() async throws {
        // Arrange
        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: []
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(response.successfulEntries.isEmpty)
        XCTAssertTrue(response.failedImages.isEmpty)
        XCTAssertEqual(response.totalImages, 0)
    }

    func test_execute_withOneImage_shouldCallOCR() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("test_image.png")
        try createDummyImageFile(at: url)

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [url]
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockOCR.recognizeTextFromImageCalled)
    }

    func test_execute_withOneImage_shouldCallSaveEntry() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("test_image_save.png")
        try createDummyImageFile(at: url)

        let projectId = Identifier<Project>()
        let request = ProcessImageBatchRequest(
            projectId: projectId,
            imageURLs: [url]
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertTrue(mockSaveAudioEntry.executeCalled)
        }
    }

    func test_execute_withMultipleImages_shouldProcessAll() async throws {
        // Arrange
        let urls = (1...3).map { tempDir.appendingPathComponent("batch_test_\($0).png") }
        for url in urls {
            try createDummyImageFile(at: url)
        }

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: urls
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalImages, 3)
        XCTAssertEqual(response.successCount, 3)
    }

    func test_execute_shouldReportProgress() async throws {
        // Arrange
        let urls = (1...2).map { tempDir.appendingPathComponent("progress_test_\($0).png") }
        for url in urls {
            try createDummyImageFile(at: url)
        }

        var progressUpdates: [(Int, Int)] = []
        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: urls,
            onProgress: { current, total in
                progressUpdates.append((current, total))
            }
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        XCTAssertEqual(progressUpdates.count, 2)
        XCTAssertEqual(progressUpdates[0].0, 1)
        XCTAssertEqual(progressUpdates[0].1, 2)
        XCTAssertEqual(progressUpdates[1].0, 2)
        XCTAssertEqual(progressUpdates[1].1, 2)
    }

    func test_execute_whenOCRFails_shouldContinueWithOthers() async throws {
        // Arrange - first file doesn't exist (will fail), second does
        let badURL = tempDir.appendingPathComponent("nonexistent.png")
        let goodURL = tempDir.appendingPathComponent("good_image.png")
        try createDummyImageFile(at: goodURL)

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [badURL, goodURL]
        )

        // Act
        let response = try await sut.execute(request)

        // Assert - first failed (no file), second succeeded
        XCTAssertEqual(response.successCount, 1)
        XCTAssertEqual(response.failureCount, 1)
    }

    func test_execute_whenOCRFails_shouldRecordFailure() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("ocr_record_fail.png")
        try createDummyImageFile(at: url)

        mockOCR.errorToThrow = OCRError.noTextFound

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [url]
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.failureCount, 1)
        XCTAssertEqual(response.failedImages[0].fileName, "ocr_record_fail.png")
        XCTAssertFalse(response.failedImages[0].reason.isEmpty)
    }

    func test_execute_whenSaveFails_shouldRecordFailure() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("save_fail_test.png")
        try createDummyImageFile(at: url)

        await MainActor.run {
            mockSaveAudioEntry.errorToThrow = ApplicationError.projectNotFound
        }

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [url]
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.failureCount, 1)
        XCTAssertEqual(response.failedImages[0].fileName, "save_fail_test.png")
    }

    func test_execute_shouldPassCorrectProjectId() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("projectid_test.png")
        try createDummyImageFile(at: url)

        let projectId = Identifier<Project>()
        let request = ProcessImageBatchRequest(
            projectId: projectId,
            imageURLs: [url]
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertEqual(mockSaveAudioEntry.lastRequest?.projectId, projectId)
        }
    }

    func test_execute_shouldPassImagePathToSaveRequest() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("imagepath_test.png")
        try createDummyImageFile(at: url)

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [url]
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertEqual(mockSaveAudioEntry.lastRequest?.imagePath, url.path)
        }
    }

    func test_execute_shouldPassNoAudioData() async throws {
        // Arrange
        let url = tempDir.appendingPathComponent("noaudio_test.png")
        try createDummyImageFile(at: url)

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: [url]
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertNil(mockSaveAudioEntry.lastRequest?.audioData)
            XCTAssertNil(mockSaveAudioEntry.lastRequest?.audioDuration)
        }
    }

    func test_execute_shouldReturnCorrectCounts() async throws {
        // Arrange
        let goodURLs = (1...2).map { tempDir.appendingPathComponent("count_test_\($0).png") }
        for url in goodURLs {
            try createDummyImageFile(at: url)
        }
        let badURL = tempDir.appendingPathComponent("nonexistent_count.png")

        let allURLs = goodURLs + [badURL]
        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: allURLs
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalImages, 3)
        XCTAssertEqual(response.successCount, 2)
        XCTAssertEqual(response.failureCount, 1)
    }

    func test_execute_withAllFailures_shouldReturnAllFailed() async throws {
        // Arrange - none of these files exist
        let urls = (1...2).map { tempDir.appendingPathComponent("allfail_nonexistent_\($0).png") }

        let request = ProcessImageBatchRequest(
            projectId: Identifier<Project>(),
            imageURLs: urls
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalImages, 2)
        XCTAssertEqual(response.successCount, 0)
        XCTAssertEqual(response.failureCount, 2)
    }

    // MARK: - Helpers

    private func createDummyImageFile(at url: URL) throws {
        let dummyData = Data(repeating: 0xFF, count: 100)
        try dummyData.write(to: url)
    }
}
