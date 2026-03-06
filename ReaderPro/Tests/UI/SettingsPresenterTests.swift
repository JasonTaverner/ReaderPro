import XCTest
@testable import ReaderPro

/// Tests para SettingsPresenter usando TDD
@MainActor
final class SettingsPresenterTests: XCTestCase {

    // MARK: - Properties

    var sut: SettingsPresenter!
    var storageConfiguration: StorageConfiguration!
    var testDefaults: UserDefaults!
    var mockSession: MockURLSession!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        testDefaults = UserDefaults(suiteName: "SettingsPresenterTests_\(UUID().uuidString)")!
        storageConfiguration = StorageConfiguration(userDefaults: testDefaults)
        mockSession = MockURLSession()

        let adapter = Qwen3TTSAdapter(
            baseURL: URL(string: "http://localhost:8890")!,
            urlSession: mockSession
        )
        sut = SettingsPresenter(storageConfiguration: storageConfiguration, qwen3Adapter: adapter)
    }

    override func tearDown() {
        sut = nil
        storageConfiguration = nil
        testDefaults = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - OnAppear Tests

    func test_onAppear_shouldLoadCurrentDirectory() {
        // Act
        sut.onAppear()

        // Assert
        XCTAssertFalse(sut.viewModel.currentDirectoryPath.isEmpty)
    }

    func test_onAppear_whenDefault_shouldShowDefaultPath() {
        // Act
        sut.onAppear()

        // Assert
        XCTAssertTrue(sut.viewModel.currentDirectoryPath.contains("ReaderProLibrary"))
        XCTAssertFalse(sut.viewModel.isCustomDirectory)
    }

    func test_onAppear_whenCustom_shouldShowCustomPath() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsPresenterTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try storageConfiguration.setBaseDirectory(tempDir)

        // Recreate presenter so it picks up the new config
        let adapter = Qwen3TTSAdapter(
            baseURL: URL(string: "http://localhost:8890")!,
            urlSession: mockSession
        )
        sut = SettingsPresenter(storageConfiguration: storageConfiguration, qwen3Adapter: adapter)

        // Act
        sut.onAppear()

        // Assert
        XCTAssertTrue(sut.viewModel.isCustomDirectory)
    }

    // MARK: - Reset Tests

    func test_resetToDefault_shouldClearCustomDirectory() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsPresenterTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try storageConfiguration.setBaseDirectory(tempDir)
        sut.onAppear()
        XCTAssertTrue(sut.viewModel.isCustomDirectory)

        // Act
        sut.resetToDefault()

        // Assert
        XCTAssertFalse(sut.viewModel.isCustomDirectory)
        XCTAssertTrue(sut.viewModel.currentDirectoryPath.contains("ReaderProLibrary"))
    }

    func test_resetToDefault_shouldShowRestartAlert() {
        // Act
        sut.resetToDefault()

        // Assert
        XCTAssertTrue(sut.viewModel.showRestartAlert)
    }

    // MARK: - Init Tests

    func test_init_shouldHaveDefaultViewModel() {
        // Assert
        XCTAssertEqual(sut.viewModel.currentDirectoryPath, "")
        XCTAssertFalse(sut.viewModel.isCustomDirectory)
        XCTAssertFalse(sut.viewModel.showRestartAlert)
        XCTAssertNil(sut.viewModel.error)
    }
}
