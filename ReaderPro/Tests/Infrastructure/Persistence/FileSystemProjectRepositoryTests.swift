import XCTest
@testable import ReaderPro

/// Tests de integración para FileSystemProjectRepository
/// Usa un directorio temporal para las pruebas
final class FileSystemProjectRepositoryTests: XCTestCase {

    // MARK: - Properties

    var sut: FileSystemProjectRepository!
    var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        // Crear directorio temporal único para cada test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        sut = FileSystemProjectRepository(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        // Limpiar directorio temporal
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func test_save_withNewProject_shouldCreateDirectory() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("Test Project"))

        // Act
        try await sut.save(project)

        // Assert - Directory should exist (named by project name)
        let projectDir = tempDirectory
            .appendingPathComponent("Test Project", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectDir.path))
    }

    func test_save_withNewProject_shouldCreateProjectJSON() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("My Project"))

        // Act
        try await sut.save(project)

        // Assert - project.json should exist (in directory named by project name)
        let projectDir = tempDirectory.appendingPathComponent("My Project", isDirectory: true)
        let jsonFile = projectDir.appendingPathComponent("project.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonFile.path))
    }

    func test_save_withExistingProject_shouldUpdateJSON() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        try await sut.save(project)

        // Modify project
        try project.rename(try! ProjectName("Updated Name"))

        // Act
        try await sut.save(project)

        // Assert - Should retrieve updated project
        let retrieved = try await sut.findById(project.id)
        XCTAssertEqual(retrieved?.name.value, "Updated Name")
    }

    func test_save_withProjectWithAudio_shouldPersistAudioPath() async throws {
        // Arrange
        let project = TestFixtures.makeProjectWithAudio(audioPath: "/audio/test.wav")

        // Act
        try await sut.save(project)

        // Assert
        let retrieved = try await sut.findById(project.id)
        XCTAssertEqual(retrieved?.audioPath, "/audio/test.wav")
        XCTAssertTrue(retrieved!.hasAudio)
    }

    func test_save_withProjectWithEntries_shouldPersistEntries() async throws {
        // Arrange
        var project = TestFixtures.makeProject()
        let entry1 = TestFixtures.makeAudioEntry()
        let entry2 = TestFixtures.makeAudioEntry()
        try! project.addEntry(entry1)
        try! project.addEntry(entry2)

        // Act
        try await sut.save(project)

        // Assert
        let retrieved = try await sut.findById(project.id)
        XCTAssertEqual(retrieved?.entries.count, 2)
    }

    // MARK: - FindById Tests

    func test_findById_withExistingProject_shouldReturnProject() async throws {
        // Arrange
        let project = TestFixtures.makeProject(
            name: try! ProjectName("Find Me"),
            text: try! TextContent("Some text content")
        )
        try await sut.save(project)

        // Act
        let retrieved = try await sut.findById(project.id)

        // Assert
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, project.id)
        XCTAssertEqual(retrieved?.name.value, "Find Me")
        XCTAssertEqual(retrieved?.text?.value, "Some text content")
        XCTAssertEqual(retrieved?.status, project.status)
    }

    func test_findById_withNonexistentProject_shouldReturnNil() async throws {
        // Arrange
        let nonexistentId = Identifier<Project>()

        // Act
        let result = try await sut.findById(nonexistentId)

        // Assert
        XCTAssertNil(result)
    }

    func test_findById_shouldReconstructVoiceConfiguration() async throws {
        // Arrange
        let voiceConfig = VoiceConfiguration(
            voiceId: "test-voice",
            speed: try! VoiceConfiguration.Speed(1.5)
        )
        let project = TestFixtures.makeProject(voiceConfiguration: voiceConfig)
        try await sut.save(project)

        // Act
        let retrieved = try await sut.findById(project.id)

        // Assert
        XCTAssertEqual(retrieved?.voiceConfiguration.voiceId, "test-voice")
        XCTAssertEqual(retrieved?.voiceConfiguration.speed.value, 1.5)
    }

    // MARK: - FindAll Tests

    func test_findAll_withNoProjects_shouldReturnEmptyArray() async throws {
        // Act
        let projects = try await sut.findAll()

        // Assert
        XCTAssertTrue(projects.isEmpty)
    }

    func test_findAll_withMultipleProjects_shouldReturnAll() async throws {
        // Arrange
        let project1 = TestFixtures.makeProject(name: try! ProjectName("Project 1"))
        let project2 = TestFixtures.makeProject(name: try! ProjectName("Project 2"))
        let project3 = TestFixtures.makeProject(name: try! ProjectName("Project 3"))

        try await sut.save(project1)
        try await sut.save(project2)
        try await sut.save(project3)

        // Act
        let projects = try await sut.findAll()

        // Assert
        XCTAssertEqual(projects.count, 3)
        let names = projects.map { $0.name.value }
        XCTAssertTrue(names.contains("Project 1"))
        XCTAssertTrue(names.contains("Project 2"))
        XCTAssertTrue(names.contains("Project 3"))
    }

    func test_findAll_shouldSortByUpdatedAtDescending() async throws {
        // Arrange
        let old = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Old"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 1000)
        )

        let recent = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Recent"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: Date(timeIntervalSince1970: 2000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )

        try await sut.save(old)
        try await sut.save(recent)

        // Act
        let projects = try await sut.findAll()

        // Assert - Should be sorted by updatedAt descending (newest first)
        XCTAssertEqual(projects[0].name.value, "Recent")
        XCTAssertEqual(projects[1].name.value, "Old")
    }

    // MARK: - Delete Tests

    func test_delete_withExistingProject_shouldRemoveDirectory() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("To Delete"))
        try await sut.save(project)

        let projectDir = tempDirectory.appendingPathComponent("To Delete", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectDir.path))

        // Act
        try await sut.delete(project.id)

        // Assert - Directory should be removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectDir.path))
    }

    func test_delete_withExistingProject_shouldNotBeRetrievable() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        try await sut.save(project)

        // Act
        try await sut.delete(project.id)

        // Assert
        let retrieved = try await sut.findById(project.id)
        XCTAssertNil(retrieved)
    }

    func test_delete_withNonexistentProject_shouldNotThrow() async throws {
        // Arrange
        let nonexistentId = Identifier<Project>()

        // Act & Assert - Should not throw
        try await sut.delete(nonexistentId)
    }

    // MARK: - Search Tests

    func test_search_withMatchingName_shouldReturnProjects() async throws {
        // Arrange
        let project1 = TestFixtures.makeProject(name: try! ProjectName("iOS Development"))
        let project2 = TestFixtures.makeProject(name: try! ProjectName("Android Development"))
        let project3 = TestFixtures.makeProject(name: try! ProjectName("Web Design"))

        try await sut.save(project1)
        try await sut.save(project2)
        try await sut.save(project3)

        // Act
        let results = try await sut.search(query: "Development")

        // Assert
        XCTAssertEqual(results.count, 2)
        let names = results.map { $0.name.value }
        XCTAssertTrue(names.contains("iOS Development"))
        XCTAssertTrue(names.contains("Android Development"))
        XCTAssertFalse(names.contains("Web Design"))
    }

    func test_search_withMatchingText_shouldReturnProjects() async throws {
        // Arrange
        let project1 = TestFixtures.makeProject(
            name: try! ProjectName("Project 1"),
            text: try! TextContent("This talks about Swift programming")
        )
        let project2 = TestFixtures.makeProject(
            name: try! ProjectName("Project 2"),
            text: try! TextContent("This talks about Python programming")
        )

        try await sut.save(project1)
        try await sut.save(project2)

        // Act
        let results = try await sut.search(query: "Swift")

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name.value, "Project 1")
    }

    func test_search_withNoMatches_shouldReturnEmpty() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("Test"))
        try await sut.save(project)

        // Act
        let results = try await sut.search(query: "NonExistentQuery")

        // Assert
        XCTAssertTrue(results.isEmpty)
    }

    func test_search_shouldBeCaseInsensitive() async throws {
        // Arrange
        let project = TestFixtures.makeProject(name: try! ProjectName("Important Project"))
        try await sut.save(project)

        // Act
        let results1 = try await sut.search(query: "important")
        let results2 = try await sut.search(query: "IMPORTANT")
        let results3 = try await sut.search(query: "ImPoRtAnT")

        // Assert
        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results3.count, 1)
    }

    // MARK: - FindByStatus Tests

    func test_findByStatus_shouldFilterCorrectly() async throws {
        // Arrange
        let draft1 = TestFixtures.makeProject(name: try! ProjectName("Draft 1"))
        let draft2 = TestFixtures.makeProject(name: try! ProjectName("Draft 2"))
        let ready = TestFixtures.makeProjectWithAudio()
        var error = TestFixtures.makeProject(name: try! ProjectName("Error"))
        error.markError()

        try await sut.save(draft1)
        try await sut.save(draft2)
        try await sut.save(ready)
        try await sut.save(error)

        // Act
        let drafts = try await sut.findByStatus(.draft)
        let readyProjects = try await sut.findByStatus(.ready)
        let errorProjects = try await sut.findByStatus(.error)

        // Assert
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(readyProjects.count, 1)
        XCTAssertEqual(errorProjects.count, 1)
    }

    // MARK: - FindCreatedAfter Tests

    func test_findCreatedAfter_shouldFilterCorrectly() async throws {
        // Arrange
        let cutoffDate = Date(timeIntervalSince1970: 1500)

        let oldProject = Project(
            id: Identifier<Project>(),
            name: try! ProjectName("Old"),
            text: try! TextContent("TextContent"),
            voiceConfiguration: TestFixtures.makeVoiceConfiguration(),
            voice: TestFixtures.makeVoice(),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 1000)
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
            createdAt: Date(timeIntervalSince1970: 2000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )

        try await sut.save(oldProject)
        try await sut.save(newProject)

        // Act
        let results = try await sut.findCreatedAfter(cutoffDate)

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name.value, "New")
    }

    // MARK: - Integration Tests

    func test_fullLifecycle_createUpdateDelete() async throws {
        // Create
        var project = TestFixtures.makeProject(name: try! ProjectName("Lifecycle Test"))
        try await sut.save(project)

        // Verify created
        var retrieved = try await sut.findById(project.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name.value, "Lifecycle Test")

        // Update
        try project.rename(try! ProjectName("Updated Lifecycle"))
        try await sut.save(project)

        // Verify updated
        retrieved = try await sut.findById(project.id)
        XCTAssertEqual(retrieved?.name.value, "Updated Lifecycle")

        // Delete
        try await sut.delete(project.id)

        // Verify deleted
        retrieved = try await sut.findById(project.id)
        XCTAssertNil(retrieved)
    }

    func test_concurrentSaves_shouldNotCorruptData() async throws {
        // Arrange
        let projects = (1...10).map { i in
            TestFixtures.makeProject(name: try! ProjectName("Project \(i)"))
        }

        // Act - Save concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for project in projects {
                group.addTask {
                    try await self.sut.save(project)
                }
            }
            try await group.waitForAll()
        }

        // Assert
        let allProjects = try await sut.findAll()
        XCTAssertEqual(allProjects.count, 10)
    }
}
