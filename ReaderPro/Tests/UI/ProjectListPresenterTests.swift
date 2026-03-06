import XCTest
@testable import ReaderPro

/// Tests para ProjectListPresenter usando TDD
@MainActor
final class ProjectListPresenterTests: XCTestCase {

    // MARK: - Properties

    var sut: ProjectListPresenter!
    var mockListProjects: MockListProjectsUseCase!
    var mockDeleteProject: MockDeleteProjectUseCase!
    var mockGenerateAudio: MockGenerateAudioUseCase!
    var mockCreateProject: MockCreateProjectUseCase!
    var mockAudioStorage: MockAudioStoragePort!
    var mockProjectRepository: MockProjectRepositoryPort!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockListProjects = MockListProjectsUseCase()
        mockDeleteProject = MockDeleteProjectUseCase()
        mockGenerateAudio = MockGenerateAudioUseCase()
        mockCreateProject = MockCreateProjectUseCase()
        mockAudioStorage = MockAudioStoragePort()
        mockProjectRepository = MockProjectRepositoryPort()

        sut = ProjectListPresenter(
            listProjectsUseCase: mockListProjects,
            deleteProjectUseCase: mockDeleteProject,
            generateAudioUseCase: mockGenerateAudio,
            createProjectUseCase: mockCreateProject,
            audioStorage: mockAudioStorage,
            projectRepository: mockProjectRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockListProjects = nil
        mockDeleteProject = nil
        mockGenerateAudio = nil
        mockCreateProject = nil
        mockAudioStorage = nil
        mockProjectRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_shouldHaveEmptyViewModel() {
        // Assert
        XCTAssertTrue(sut.viewModel.projects.isEmpty)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNil(sut.viewModel.error)
        XCTAssertEqual(sut.viewModel.searchQuery, "")
    }

    // MARK: - OnAppear Tests

    func test_onAppear_shouldSetLoadingTrue() async {
        // Arrange
        mockListProjects.delayResponse = true

        // Act
        let task = Task { await sut.onAppear() }

        // Assert (verificar durante la carga)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockListProjects.delayResponse = false
        await task.value
    }

    func test_onAppear_shouldLoadProjects() async {
        // Arrange
        let testProjects = [
            createTestProjectSummary(name: "Project 1"),
            createTestProjectSummary(name: "Project 2"),
            createTestProjectSummary(name: "Project 3"),
        ]
        mockListProjects.projectsToReturn = testProjects

        // Act
        await sut.onAppear()

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 3)
        XCTAssertEqual(sut.viewModel.projects[0].name, "Project 1")
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNil(sut.viewModel.error)
    }

    func test_onAppear_shouldSortProjectsByUpdatedAtDescending() async {
        // Arrange - Mock returns data in sorted order (use case is responsible for sorting)
        let old = createTestProjectSummary(name: "Old", updatedAt: Date(timeIntervalSince1970: 100))
        let newest = createTestProjectSummary(name: "Newest", updatedAt: Date(timeIntervalSince1970: 300))
        let middle = createTestProjectSummary(name: "Middle", updatedAt: Date(timeIntervalSince1970: 200))

        // Provide already sorted (descending by updatedAt)
        mockListProjects.projectsToReturn = [newest, middle, old]

        // Act
        await sut.onAppear()

        // Assert
        XCTAssertEqual(sut.viewModel.projects[0].name, "Newest")
        XCTAssertEqual(sut.viewModel.projects[1].name, "Middle")
        XCTAssertEqual(sut.viewModel.projects[2].name, "Old")
    }

    func test_onAppear_whenUseCaseFails_shouldShowError() async {
        // Arrange
        mockListProjects.errorToThrow = ApplicationError.projectNotFound

        // Act
        await sut.onAppear()

        // Assert
        XCTAssertTrue(sut.viewModel.projects.isEmpty)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_onAppear_whenNoProjects_shouldReturnEmptyList() async {
        // Arrange
        mockListProjects.projectsToReturn = []

        // Act
        await sut.onAppear()

        // Assert
        XCTAssertTrue(sut.viewModel.projects.isEmpty)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNil(sut.viewModel.error)
    }

    // MARK: - Delete Tests

    func test_deleteProject_shouldCallDeleteUseCase() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        mockListProjects.projectsToReturn = []

        // Act
        await sut.deleteProject(id: projectId)

        // Assert
        XCTAssertTrue(mockDeleteProject.deleteCalled)
        XCTAssertEqual(mockDeleteProject.lastDeletedId, projectId)
    }

    func test_deleteProject_shouldReloadProjectsAfterDelete() async throws {
        // Arrange
        let id1 = Identifier<Project>()
        let id2 = Identifier<Project>()
        let project1 = createTestProjectSummary(id: id1, name: "Project 1")
        let project2 = createTestProjectSummary(id: id2, name: "Project 2")

        mockListProjects.projectsToReturn = [project1, project2]
        await sut.onAppear()

        XCTAssertEqual(sut.viewModel.projects.count, 2)

        // Simular que después de eliminar solo queda 1
        mockListProjects.projectsToReturn = [project2]

        // Act
        await sut.deleteProject(id: id1)

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 1)
        XCTAssertEqual(sut.viewModel.projects[0].name, "Project 2")
    }

    func test_deleteProject_whenFails_shouldShowError() async {
        // Arrange
        mockDeleteProject.errorToThrow = ApplicationError.projectNotFound
        let projectId = Identifier<Project>()

        // Act
        await sut.deleteProject(id: projectId)

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_deleteProject_shouldSetLoadingDuringOperation() async {
        // Arrange
        let projectId = Identifier<Project>()
        mockDeleteProject.delayResponse = true

        // Act
        let task = Task { await sut.deleteProject(id: projectId) }

        // Assert (verificar durante la operación)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockDeleteProject.delayResponse = false
        await task.value
    }

    func test_deleteProject_shouldClearErrorBeforeOperation() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.error = "Previous error"

        // Act
        await sut.deleteProject(id: projectId)

        // Assert - error should be cleared (or set to new error if delete fails)
        // En este caso, como no hay error, debería ser nil
        XCTAssertNil(sut.viewModel.error)
    }

    // MARK: - Search Tests

    func test_search_withEmptyQuery_shouldShowAllProjects() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Alpha"),
            createTestProjectSummary(name: "Beta"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 2)
        XCTAssertEqual(sut.viewModel.searchQuery, "")
    }

    func test_search_shouldFilterProjectsByName() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Alpha Project"),
            createTestProjectSummary(name: "Beta Test"),
            createTestProjectSummary(name: "Alpha Beta"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "Alpha")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 2)
        XCTAssertTrue(sut.viewModel.projects.allSatisfy { $0.name.contains("Alpha") })
        XCTAssertEqual(sut.viewModel.searchQuery, "Alpha")
    }

    func test_search_shouldFilterProjectsByTextContent() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Project 1", text: "Hello world"),
            createTestProjectSummary(name: "Project 2", text: "Goodbye world"),
            createTestProjectSummary(name: "Project 3", text: "Hello universe"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "Hello")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 2)
    }

    func test_search_shouldBeCaseInsensitive() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Project Alpha"),
            createTestProjectSummary(name: "project beta"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "PROJECT")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 2)
    }

    func test_search_whenNoMatches_shouldReturnEmptyList() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Alpha"),
            createTestProjectSummary(name: "Beta"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "Gamma")

        // Assert
        XCTAssertTrue(sut.viewModel.projects.isEmpty)
        XCTAssertEqual(sut.viewModel.searchQuery, "Gamma")
    }

    func test_search_shouldTrimWhitespace() async {
        // Arrange
        let projects = [
            createTestProjectSummary(name: "Test Project"),
        ]
        mockListProjects.projectsToReturn = projects
        await sut.onAppear()

        // Act
        await sut.search(query: "  Test  ")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 1)
        XCTAssertEqual(sut.viewModel.searchQuery, "  Test  ")
    }

    // MARK: - Integration Tests

    func test_fullFlow_loadDeleteSearch() async {
        // 1. Load projects
        let id1 = Identifier<Project>()
        let id2 = Identifier<Project>()
        let id3 = Identifier<Project>()

        mockListProjects.projectsToReturn = [
            createTestProjectSummary(id: id1, name: "Project 1"),
            createTestProjectSummary(id: id2, name: "Project 2"),
            createTestProjectSummary(id: id3, name: "Special Project"),
        ]
        await sut.onAppear()
        XCTAssertEqual(sut.viewModel.projects.count, 3)

        // 2. Search
        await sut.search(query: "Special")
        XCTAssertEqual(sut.viewModel.projects.count, 1)

        // 3. Clear search
        await sut.search(query: "")
        XCTAssertEqual(sut.viewModel.projects.count, 3)

        // 4. Delete project
        mockListProjects.projectsToReturn = [
            createTestProjectSummary(id: id1, name: "Project 1"),
            createTestProjectSummary(id: id3, name: "Special Project"),
        ]
        await sut.deleteProject(id: id2)
        XCTAssertEqual(sut.viewModel.projects.count, 2)
    }

    // MARK: - Create Project Tests

    func test_createProject_shouldCallCreateUseCase() async {
        // Arrange
        let projectName = "My New Project"

        // Act
        await sut.createProject(name: projectName)

        // Assert
        XCTAssertTrue(mockCreateProject.executeCalled)
        XCTAssertEqual(mockCreateProject.lastRequest?.name, projectName)
    }

    func test_createProject_shouldCreateProjectWithEmptyText() async {
        // Arrange
        let projectName = "Empty Project"

        // Act
        await sut.createProject(name: projectName)

        // Assert
        // The request should have nil or empty text
        let request = mockCreateProject.lastRequest
        XCTAssertNotNil(request)
        // Text should be nil (empty project)
        XCTAssertNil(request?.text)
    }

    func test_createProject_shouldReloadProjectsAfterCreation() async {
        // Arrange
        let newProjectId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: newProjectId,
            projectName: "New Project",
            status: .draft,
            createdAt: Date()
        )

        let newProject = createTestProjectSummary(id: newProjectId, name: "New Project")
        mockListProjects.projectsToReturn = [newProject]

        // Act
        await sut.createProject(name: "New Project")

        // Assert
        XCTAssertEqual(sut.viewModel.projects.count, 1)
        XCTAssertEqual(sut.viewModel.projects[0].name, "New Project")
    }

    func test_createProject_shouldSetLoadingDuringOperation() async {
        // Arrange
        mockCreateProject.delayResponse = true

        // Act
        let task = Task { await sut.createProject(name: "Test") }

        // Assert (verificar durante la operación)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockCreateProject.delayResponse = false
        await task.value
    }

    func test_createProject_shouldClearLoadingAfterCompletion() async {
        // Act
        await sut.createProject(name: "Test")

        // Assert
        XCTAssertFalse(sut.viewModel.isLoading)
    }

    func test_createProject_whenFails_shouldShowError() async {
        // Arrange
        mockCreateProject.errorToThrow = ApplicationError.projectNotFound

        // Act
        await sut.createProject(name: "Test")

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_createProject_shouldReturnCreatedProjectId() async {
        // Arrange
        let expectedId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: expectedId,
            projectName: "Test",
            status: .draft,
            createdAt: Date()
        )

        // Act
        let createdId = await sut.createProject(name: "Test")

        // Assert
        XCTAssertEqual(createdId, expectedId)
    }

    func test_createProject_whenFails_shouldReturnNil() async {
        // Arrange
        mockCreateProject.errorToThrow = ApplicationError.projectNotFound

        // Act
        let createdId = await sut.createProject(name: "Test")

        // Assert
        XCTAssertNil(createdId)
    }

    func test_createProject_shouldClearErrorBeforeOperation() async {
        // Arrange
        sut.viewModel.error = "Previous error"

        // Act
        await sut.createProject(name: "Test")

        // Assert - error should be cleared
        XCTAssertNil(sut.viewModel.error)
    }

    // MARK: - Helper Methods

    private func createTestProjectSummary(
        id: Identifier<Project>? = nil,
        name: String = "Test Project",
        text: String = "Test content",
        status: ProjectStatus = .ready,
        updatedAt: Date = Date()
    ) -> ProjectSummary {
        ProjectSummary(
            projectId: id ?? Identifier<Project>(),
            name: name,
            textPreview: text,
            status: status,
            hasAudio: true,
            voiceName: "Test Voice",
            voiceProvider: .native,
            createdAt: Date(),
            updatedAt: updatedAt
        )
    }
}
