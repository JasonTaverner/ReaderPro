import XCTest
@testable import ReaderPro

/// Tests para StorageConfiguration usando TDD
final class StorageConfigurationTests: XCTestCase {

    // MARK: - Properties

    var sut: StorageConfiguration!
    var testDefaults: UserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "StorageConfigurationTests_\(UUID().uuidString)")!
        sut = StorageConfiguration(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.volatileDomainNames.first ?? "")
        sut = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Default Directory Tests

    func test_defaultDirectory_shouldBeReaderProLibrary() {
        // Arrange
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let expected = documentsDir.appendingPathComponent("ReaderProLibrary", isDirectory: true)

        // Act
        let result = sut.defaultDirectory

        // Assert
        XCTAssertEqual(result, expected)
    }

    func test_baseDirectory_whenNoCustomSet_shouldReturnDefault() {
        // Act
        let result = sut.baseDirectory

        // Assert
        XCTAssertEqual(result, sut.defaultDirectory)
    }

    func test_isCustomDirectory_whenDefault_shouldReturnFalse() {
        // Act & Assert
        XCTAssertFalse(sut.isCustomDirectory)
    }

    // MARK: - Custom Directory Tests

    func test_setBaseDirectory_shouldPersistPath() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StorageConfigTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Act
        try sut.setBaseDirectory(tempDir)

        // Assert
        let savedPath = testDefaults.string(forKey: "storageBaseDirectory")
        XCTAssertEqual(savedPath, tempDir.path)
    }

    func test_baseDirectory_afterSet_shouldReturnCustom() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StorageConfigTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Act
        try sut.setBaseDirectory(tempDir)

        // Assert — recreate sut to simulate app restart
        let freshConfig = StorageConfiguration(userDefaults: testDefaults)
        XCTAssertNotEqual(freshConfig.baseDirectory, freshConfig.defaultDirectory)
    }

    func test_isCustomDirectory_afterSet_shouldReturnTrue() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StorageConfigTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Act
        try sut.setBaseDirectory(tempDir)

        // Assert — recreate sut to simulate app restart
        let freshConfig = StorageConfiguration(userDefaults: testDefaults)
        XCTAssertTrue(freshConfig.isCustomDirectory)
    }

    // MARK: - Reset Tests

    func test_resetToDefault_shouldClearCustomPath() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StorageConfigTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try sut.setBaseDirectory(tempDir)

        // Act
        sut.resetToDefault()

        // Assert
        let freshConfig = StorageConfiguration(userDefaults: testDefaults)
        XCTAssertFalse(freshConfig.isCustomDirectory)
        XCTAssertEqual(freshConfig.baseDirectory, freshConfig.defaultDirectory)
    }

    // MARK: - Isolation Tests

    func test_init_withCustomUserDefaults_shouldIsolate() {
        // Arrange
        let otherDefaults = UserDefaults(suiteName: "StorageConfigurationTests_Other_\(UUID().uuidString)")!
        let otherConfig = StorageConfiguration(userDefaults: otherDefaults)

        // Act & Assert
        // Each instance uses its own UserDefaults, so they are independent
        XCTAssertFalse(sut.isCustomDirectory)
        XCTAssertFalse(otherConfig.isCustomDirectory)
        XCTAssertEqual(sut.baseDirectory, otherConfig.baseDirectory)
    }
}
