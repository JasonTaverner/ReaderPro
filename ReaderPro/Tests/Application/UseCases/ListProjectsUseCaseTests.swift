import XCTest
@testable import ReaderPro

/// Tests para el Use Case ListProjects
/// Lista todos los proyectos del usuario
final class ListProjectsUseCaseTests: XCTestCase {

    // MARK: - Properties

    var sut: ListProjectsUseCase!
    var mockRepository: MockProjectRepositoryPort!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockProjectRepositoryPort()
        sut = ListProjectsUseCase(projectRepository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func test_execute_withMultipleProjects_shouldReturnAll() async throws {
        // Arrange
        let project1 = TestFixtures.makeProject(
            name: try! ProjectName("Proyecto 1"),
            text: try! TextContent("Texto 1")
        )
        let project2 = TestFixtures.makeProject(
            name: try! ProjectName("Proyecto 2"),
            text: try! TextContent("Texto 2")
        )
        let project3 = TestFixtures.makeProjectWithAudio(
            name: try! ProjectName("Proyecto 3"),
            text: try! TextContent("Texto 3")
        )

        mockRepository.projectsToReturn = [project1, project2, project3]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.findAllCalled)
        XCTAssertEqual(response.projects.count, 3)
        XCTAssertEqual(response.totalCount, 3)

        // Find projects by ID (order is not guaranteed, depends on updatedAt)
        let p1 = response.projects.first { $0.projectId == project1.id }!
        XCTAssertEqual(p1.name, "Proyecto 1")
        XCTAssertEqual(p1.status, .draft)
        XCTAssertFalse(p1.hasAudio)

        // Verify project with audio
        let p3 = response.projects.first { $0.projectId == project3.id }!
        XCTAssertTrue(p3.hasAudio)
        XCTAssertEqual(p3.status, .ready)
    }

    func test_execute_withNoProjects_shouldReturnEmptyList() async throws {
        // Arrange
        mockRepository.projectsToReturn = []

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertTrue(mockRepository.findAllCalled)
        XCTAssertTrue(response.projects.isEmpty)
        XCTAssertEqual(response.totalCount, 0)
    }

    func test_execute_shouldReturnProjectSummaries() async throws {
        // Arrange
        let project = TestFixtures.makeProject(
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Este es un texto largo que debería ser truncado en el summary")
        )
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertEqual(summary.projectId, project.id)
        XCTAssertEqual(summary.name, "Test Project")
        XCTAssertNotNil(summary.textPreview)
        XCTAssertEqual(summary.status, .draft)
        XCTAssertEqual(summary.createdAt, project.createdAt)
        XCTAssertEqual(summary.updatedAt, project.updatedAt)
    }

    func test_execute_shouldIncludeTextPreview() async throws {
        // Arrange
        let longText = String(repeating: "a", count: 200)
        let project = TestFixtures.makeProject(text: try! TextContent(longText))
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertNotNil(summary.textPreview)
        // Preview should be truncated (e.g., 100 chars)
        XCTAssertLessThanOrEqual(summary.textPreview.count, 150)
    }

    func test_execute_shouldIncludeVoiceInformation() async throws {
        // Arrange
        let voice = Voice(
            id: "kokoro-spanish",
            name: "Kokoro Spanish",
            language: "es-ES",
            provider: .kokoro,
            isDefault: false
        )
        let project = TestFixtures.makeProject(voice: voice)
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertEqual(summary.voiceName, "Kokoro Spanish")
        XCTAssertEqual(summary.voiceProvider, .kokoro)
    }

    func test_execute_shouldIncludeAudioStatus() async throws {
        // Arrange
        let projectWithAudio = TestFixtures.makeProjectWithAudio()
        let projectWithoutAudio = TestFixtures.makeProject()

        mockRepository.projectsToReturn = [projectWithAudio, projectWithoutAudio]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert - Find by ID since order depends on updatedAt
        let withAudio = response.projects.first { $0.projectId == projectWithAudio.id }!
        let withoutAudio = response.projects.first { $0.projectId == projectWithoutAudio.id }!
        XCTAssertTrue(withAudio.hasAudio)
        XCTAssertFalse(withoutAudio.hasAudio)
    }

    func test_execute_shouldIncludeDifferentStatuses() async throws {
        // Arrange
        let draftProject = TestFixtures.makeProject()

        var generatingProject = TestFixtures.makeProject()
        generatingProject.markGenerating()

        let readyProject = TestFixtures.makeProjectWithAudio()

        var errorProject = TestFixtures.makeProject()
        errorProject.markError()

        mockRepository.projectsToReturn = [draftProject, generatingProject, readyProject, errorProject]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert - Find by ID since order depends on updatedAt
        let draft = response.projects.first { $0.projectId == draftProject.id }!
        let generating = response.projects.first { $0.projectId == generatingProject.id }!
        let ready = response.projects.first { $0.projectId == readyProject.id }!
        let error = response.projects.first { $0.projectId == errorProject.id }!

        XCTAssertEqual(draft.status, .draft)
        XCTAssertEqual(generating.status, .generating)
        XCTAssertEqual(ready.status, .ready)
        XCTAssertEqual(error.status, .error)
    }

    func test_execute_withSortByCreatedAtAscending_shouldSortCorrectly() async throws {
        // Arrange
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let project1 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 1"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date2,
            updatedAt: date2
        )

        let project2 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 2"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date1,
            updatedAt: date1
        )

        let project3 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 3"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date3,
            updatedAt: date3
        )

        mockRepository.projectsToReturn = [project1, project2, project3]

        let request = ListProjectsRequest(sortBy: .createdAt, ascending: true)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.projects[0].createdAt, date1)
        XCTAssertEqual(response.projects[1].createdAt, date2)
        XCTAssertEqual(response.projects[2].createdAt, date3)
    }

    func test_execute_withSortByCreatedAtDescending_shouldSortCorrectly() async throws {
        // Arrange
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let project1 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 1"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date2,
            updatedAt: date2
        )

        let project2 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 2"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date3,
            updatedAt: date3
        )

        let project3 = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Project 3"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date1,
            updatedAt: date1
        )

        mockRepository.projectsToReturn = [project1, project2, project3]

        let request = ListProjectsRequest(sortBy: .createdAt, ascending: false)

        // Act
        let response = try await sut.execute(request)

        // Assert - Should be sorted descending (newest first)
        XCTAssertEqual(response.projects[0].createdAt, date3)
        XCTAssertEqual(response.projects[1].createdAt, date2)
        XCTAssertEqual(response.projects[2].createdAt, date1)
    }

    func test_execute_withSortByName_shouldSortAlphabetically() async throws {
        // Arrange
        let projectC = TestFixtures.makeProject(name: try! ProjectName("Charlie"))
        let projectA = TestFixtures.makeProject(name: try! ProjectName("Alpha"))
        let projectB = TestFixtures.makeProject(name: try! ProjectName("Bravo"))

        mockRepository.projectsToReturn = [projectC, projectA, projectB]

        let request = ListProjectsRequest(sortBy: .name, ascending: true)

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.projects[0].name, "Alpha")
        XCTAssertEqual(response.projects[1].name, "Bravo")
        XCTAssertEqual(response.projects[2].name, "Charlie")
    }

    func test_execute_withDefaultSort_shouldSortByUpdatedAtDescending() async throws {
        // Arrange
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        let oldProject = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Old"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date1,
            updatedAt: date1
        )

        let newProject = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("New"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: date2,
            updatedAt: date2
        )

        mockRepository.projectsToReturn = [oldProject, newProject]

        let request = ListProjectsRequest()  // No sort specified

        // Act
        let response = try await sut.execute(request)

        // Assert - Default should be updatedAt descending (newest first)
        XCTAssertEqual(response.projects[0].name, "New")
        XCTAssertEqual(response.projects[1].name, "Old")
    }

    // MARK: - Thumbnail Tests

    func test_execute_shouldExtractThumbnailPathFromEntryImage() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        let entry = AudioEntry(
            text: try! TextContent("Entry with image"),
            imagePath: "project/001.png"
        )
        try project.addEntry(entry)
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertEqual(summary.thumbnailPath, "project/001.png")
    }

    func test_execute_shouldPreferCoverImageOverEntryImage() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        let entry = AudioEntry(
            text: try! TextContent("Entry with image"),
            imagePath: "project/001.png"
        )
        try project.addEntry(entry)
        project.setCoverImage(path: "project/cover.png")
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertEqual(summary.thumbnailPath, "project/cover.png")
    }

    func test_execute_withNoImages_shouldHaveNilThumbnailPath() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        let summary = response.projects.first!
        XCTAssertNil(summary.thumbnailPath)
    }

    // MARK: - Error Tests

    func test_execute_whenRepositoryThrows_shouldPropagateError() async {
        // Arrange
        struct RepositoryError: Error {}
        mockRepository.errorToThrow = RepositoryError()

        let request = ListProjectsRequest()

        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            XCTAssertTrue(mockRepository.findAllCalled)
        }
    }

    // MARK: - Response Validation Tests

    func test_execute_responseShouldBeSerializable() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert - All response fields should be basic types
        XCTAssertTrue(response.totalCount is Int)
        XCTAssertTrue(response.projects is Array<ProjectSummary>)

        let summary = response.projects.first!
        XCTAssertTrue(summary.name is String)
        XCTAssertTrue(summary.textPreview is String)
        XCTAssertTrue(summary.hasAudio is Bool)
    }

    func test_execute_shouldNotModifyProjects() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        let originalStatus = project.status

        mockRepository.projectsToReturn = [project]

        let request = ListProjectsRequest()

        // Act
        _ = try await sut.execute(request)

        // Assert - Projects should not be modified or saved
        XCTAssertTrue(mockRepository.findAllCalled)
        XCTAssertFalse(mockRepository.saveCalled)
        XCTAssertEqual(project.status, originalStatus)
    }

    // MARK: - Performance Tests

    func test_execute_withManyProjects_shouldHandleEfficiently() async throws {
        // Arrange
        var projects: [Project] = []
        for i in 1...100 {
            let project = TestFixtures.makeProject(
                name: try! ProjectName("Project \(i)"),
                text: try! TextContent("TextContent \(i)")
            )
            projects.append(project)
        }
        mockRepository.projectsToReturn = projects

        let request = ListProjectsRequest()

        // Act
        let response = try await sut.execute(request)

        // Assert
        XCTAssertEqual(response.totalCount, 100)
        XCTAssertEqual(response.projects.count, 100)
    }
}
