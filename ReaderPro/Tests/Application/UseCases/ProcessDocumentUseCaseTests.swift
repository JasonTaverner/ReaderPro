import XCTest
@testable import ReaderPro

/// Tests para ProcessDocumentUseCase usando TDD
final class ProcessDocumentUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: ProcessDocumentUseCase!
    var mockPDFParser: MockDocumentParserPort!
    var mockEPUBParser: MockDocumentParserPort!
    var mockSaveAudioEntry: MockSaveAudioEntryUseCase!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockPDFParser = await MockDocumentParserPort()
        mockEPUBParser = await MockDocumentParserPort()
        mockSaveAudioEntry = await MockSaveAudioEntryUseCase()

        await MainActor.run {
            mockPDFParser.supportedExtensions = ["pdf"]
            mockEPUBParser.supportedExtensions = ["epub"]
        }

        sut = ProcessDocumentUseCase(
            pdfParser: mockPDFParser,
            epubParser: mockEPUBParser,
            saveAudioEntryUseCase: mockSaveAudioEntry
        )
    }

    override func tearDown() {
        sut = nil
        mockPDFParser = nil
        mockEPUBParser = nil
        mockSaveAudioEntry = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withPDFExtension_shouldUsePDFParser() async throws {
        // Arrange
        let section = try DocumentSection(title: "Page 1", text: "Hello world", pageNumber: 1)
        await MainActor.run {
            mockPDFParser.sectionsToReturn = [section]
        }

        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: url
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertTrue(mockPDFParser.extractSectionsCalled)
            XCTAssertFalse(mockEPUBParser.extractSectionsCalled)
        }
    }

    func test_execute_withEPUBExtension_shouldUseEPUBParser() async throws {
        // Arrange
        let section = try DocumentSection(title: "Chapter 1", text: "Once upon a time", pageNumber: 1)
        await MainActor.run {
            mockEPUBParser.sectionsToReturn = [section]
        }

        let url = URL(fileURLWithPath: "/tmp/book.epub")
        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: url
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertTrue(mockEPUBParser.extractSectionsCalled)
            XCTAssertFalse(mockPDFParser.extractSectionsCalled)
        }
    }

    func test_execute_withUnsupportedExtension_shouldThrow() async {
        // Arrange
        let url = URL(fileURLWithPath: "/tmp/document.docx")
        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: url
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw unsupportedFormat error")
        } catch let error as DocumentParserError {
            if case .unsupportedFormat(let ext) = error {
                XCTAssertEqual(ext, "docx")
            } else {
                XCTFail("Expected unsupportedFormat, got \(error)")
            }
        } catch {
            XCTFail("Expected DocumentParserError, got \(error)")
        }
    }

    func test_execute_shouldCreateEntryPerSection() async throws {
        // Arrange
        let sections = [
            try DocumentSection(title: "Page 1", text: "First page text", pageNumber: 1),
            try DocumentSection(title: "Page 2", text: "Second page text", pageNumber: 2),
            try DocumentSection(title: "Page 3", text: "Third page text", pageNumber: 3),
        ]
        await MainActor.run {
            mockPDFParser.sectionsToReturn = sections
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.successCount, 3)
        await MainActor.run {
            XCTAssertEqual(mockSaveAudioEntry.executeCallCount, 3)
        }
    }

    func test_execute_shouldReportProgress() async throws {
        // Arrange
        let sections = [
            try DocumentSection(title: "Page 1", text: "First page", pageNumber: 1),
            try DocumentSection(title: "Page 2", text: "Second page", pageNumber: 2),
        ]
        await MainActor.run {
            mockPDFParser.sectionsToReturn = sections
        }

        var progressUpdates: [(Int, Int)] = []
        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf"),
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

    func test_execute_whenParserFails_shouldThrow() async {
        // Arrange
        await MainActor.run {
            mockPDFParser.errorToThrow = DocumentParserError.noTextContent
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/empty.pdf")
        )

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is DocumentParserError)
        }
    }

    func test_execute_whenSaveFails_shouldContinueAndRecordFailure() async throws {
        // Arrange
        let sections = [
            try DocumentSection(title: "Page 1", text: "First page", pageNumber: 1),
            try DocumentSection(title: "Page 2", text: "Second page", pageNumber: 2),
        ]
        await MainActor.run {
            mockPDFParser.sectionsToReturn = sections
            mockSaveAudioEntry.errorToThrow = ApplicationError.projectNotFound
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.successCount, 0)
        XCTAssertEqual(response.failureCount, 2)
        XCTAssertEqual(response.failedSections[0].title, "Page 1")
        XCTAssertEqual(response.failedSections[1].title, "Page 2")
    }

    func test_execute_shouldPassCorrectProjectId() async throws {
        // Arrange
        let section = try DocumentSection(title: "Page 1", text: "Content", pageNumber: 1)
        let projectId = Identifier<Project>()

        await MainActor.run {
            mockPDFParser.sectionsToReturn = [section]
        }

        let request = ProcessDocumentRequest(
            projectId: projectId,
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        _ = try await sut.execute(request)

        // Assert
        await MainActor.run {
            XCTAssertEqual(mockSaveAudioEntry.lastRequest?.projectId, projectId)
        }
    }

    func test_execute_shouldReturnCorrectCounts() async throws {
        // Arrange
        let sections = [
            try DocumentSection(title: "Page 1", text: "First page", pageNumber: 1),
            try DocumentSection(title: "Page 2", text: "Second page", pageNumber: 2),
            try DocumentSection(title: "Page 3", text: "Third page", pageNumber: 3),
        ]
        await MainActor.run {
            mockPDFParser.sectionsToReturn = sections
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalSections, 3)
        XCTAssertEqual(response.successCount, 3)
        XCTAssertEqual(response.failureCount, 0)
    }

    func test_execute_withNoSections_shouldReturnEmpty() async throws {
        // Arrange
        await MainActor.run {
            mockPDFParser.sectionsToReturn = []
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/empty.pdf")
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalSections, 0)
        XCTAssertEqual(response.successCount, 0)
        XCTAssertEqual(response.failureCount, 0)
    }

    func test_execute_shouldReturnDocumentType() async throws {
        // Arrange - PDF
        let section = try DocumentSection(title: "Page 1", text: "Content", pageNumber: 1)
        await MainActor.run {
            mockPDFParser.sectionsToReturn = [section]
        }

        let pdfRequest = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        let pdfResponse = try await sut.execute(pdfRequest)

        // Assert
        XCTAssertEqual(pdfResponse.documentType, "PDF")

        // Arrange - EPUB
        await MainActor.run {
            mockEPUBParser.sectionsToReturn = [section]
        }

        let epubRequest = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/book.epub")
        )

        // Act
        let epubResponse = try await sut.execute(epubRequest)

        // Assert
        XCTAssertEqual(epubResponse.documentType, "EPUB")
    }

    func test_execute_withMixedResults_shouldReturnPartialSuccess() async throws {
        // Arrange - 3 sections, save will fail on second one
        let sections = [
            try DocumentSection(title: "Page 1", text: "First page", pageNumber: 1),
            try DocumentSection(title: "Page 2", text: "Second page", pageNumber: 2),
            try DocumentSection(title: "Page 3", text: "Third page", pageNumber: 3),
        ]
        await MainActor.run {
            mockPDFParser.sectionsToReturn = sections
        }

        // Configure save to fail on second call
        var callCount = 0
        await MainActor.run {
            mockSaveAudioEntry.executeHandler = { _ in
                callCount += 1
                if callCount == 2 {
                    throw ApplicationError.projectNotFound
                }
                return SaveAudioEntryResponse(
                    entryId: "00\(callCount)",
                    entryNumber: callCount,
                    textPath: "General/00\(callCount).txt",
                    audioPath: "General/00\(callCount).wav",
                    imagePath: nil
                )
            }
        }

        let request = ProcessDocumentRequest(
            projectId: Identifier<Project>(),
            documentURL: URL(fileURLWithPath: "/tmp/test.pdf")
        )

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalSections, 3)
        XCTAssertEqual(response.successCount, 2)
        XCTAssertEqual(response.failureCount, 1)
        XCTAssertEqual(response.failedSections[0].title, "Page 2")
    }
}
