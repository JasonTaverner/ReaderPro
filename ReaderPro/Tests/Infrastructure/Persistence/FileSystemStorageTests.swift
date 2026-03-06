import XCTest
@testable import ReaderPro

/// Tests de integración para FileSystemStorage
/// Usa directorio temporal para las pruebas
final class FileSystemStorageTests: XCTestCase {

    // MARK: - Properties

    var sut: FileSystemStorage!
    var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        sut = FileSystemStorage(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - SaveText Tests

    func test_saveText_shouldCreateFile() async throws {
        // Arrange
        let text = "Este es un texto de prueba"
        let path = "test.txt"

        // Act
        try await sut.saveText(text, to: path)

        // Assert
        let fullPath = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_saveText_shouldWriteCorrectContent() async throws {
        // Arrange
        let text = "Contenido del archivo de prueba"
        let path = "content.txt"

        // Act
        try await sut.saveText(text, to: path)

        // Assert
        let loadedText = try await sut.loadText(from: path)
        XCTAssertEqual(loadedText, text)
    }

    func test_saveText_withUnicodeCharacters_shouldPreserve() async throws {
        // Arrange
        let text = "Texto con ñoño y 世界 y emoji 🎉"
        let path = "unicode.txt"

        // Act
        try await sut.saveText(text, to: path)

        // Assert
        let loadedText = try await sut.loadText(from: path)
        XCTAssertEqual(loadedText, text)
    }

    func test_saveText_withMultilineText_shouldPreserve() async throws {
        // Arrange
        let text = """
        Primera línea
        Segunda línea
        Tercera línea con indentación
            Cuarta línea más indentada
        """
        let path = "multiline.txt"

        // Act
        try await sut.saveText(text, to: path)

        // Assert
        let loadedText = try await sut.loadText(from: path)
        XCTAssertEqual(loadedText, text)
    }

    // MARK: - LoadText Tests

    func test_loadText_withExistingFile_shouldReturnContent() async throws {
        // Arrange
        let text = "Texto guardado"
        let path = "existing.txt"
        try await sut.saveText(text, to: path)

        // Act
        let loadedText = try await sut.loadText(from: path)

        // Assert
        XCTAssertEqual(loadedText, text)
    }

    func test_loadText_withNonexistentFile_shouldThrowError() async {
        // Arrange
        let path = "nonexistent.txt"

        // Act & Assert
        do {
            _ = try await sut.loadText(from: path)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    // MARK: - Save Data Tests

    func test_saveData_shouldCreateFile() async throws {
        // Arrange
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let path = "binary.dat"

        // Act
        try await sut.save(data: data, to: path)

        // Assert
        let fullPath = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_saveData_shouldWriteCorrectContent() async throws {
        // Arrange
        let data = Data([0xFF, 0x00, 0xAB, 0xCD])
        let path = "data.bin"

        // Act
        try await sut.save(data: data, to: path)

        // Assert
        let loadedData = try await sut.load(from: path)
        XCTAssertEqual(loadedData, data)
    }

    // MARK: - Load Data Tests

    func test_load_withExistingFile_shouldReturnData() async throws {
        // Arrange
        let data = Data(repeating: 42, count: 1024)
        let path = "large.dat"
        try await sut.save(data: data, to: path)

        // Act
        let loadedData = try await sut.load(from: path)

        // Assert
        XCTAssertEqual(loadedData.count, 1024)
        XCTAssertEqual(loadedData, data)
    }

    func test_load_withNonexistentFile_shouldThrowError() async {
        // Arrange
        let path = "nonexistent.dat"

        // Act & Assert
        do {
            _ = try await sut.load(from: path)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    // MARK: - Exists Tests

    func test_exists_withExistingFile_shouldReturnTrue() async throws {
        // Arrange
        let text = "File content"
        let path = "exists.txt"
        try await sut.saveText(text, to: path)

        // Act
        let exists = await sut.exists(path: path)

        // Assert
        XCTAssertTrue(exists)
    }

    func test_exists_withNonexistentFile_shouldReturnFalse() async {
        // Arrange
        let path = "nonexistent.txt"

        // Act
        let exists = await sut.exists(path: path)

        // Assert
        XCTAssertFalse(exists)
    }

    func test_exists_afterDelete_shouldReturnFalse() async throws {
        // Arrange
        let text = "Temporary file"
        let path = "temp.txt"
        try await sut.saveText(text, to: path)
        let existsBeforeDelete = await sut.exists(path: path)
        XCTAssertTrue(existsBeforeDelete)

        // Act
        try await sut.delete(path: path)

        // Assert
        let existsAfterDelete = await sut.exists(path: path)
        XCTAssertFalse(existsAfterDelete)
    }

    // MARK: - Delete Tests

    func test_delete_withExistingFile_shouldRemoveFile() async throws {
        // Arrange
        let text = "To be deleted"
        let path = "delete_me.txt"
        try await sut.saveText(text, to: path)

        let fullPath = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))

        // Act
        try await sut.delete(path: path)

        // Assert
        XCTAssertFalse(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_delete_withNonexistentFile_shouldNotThrow() async throws {
        // Arrange
        let path = "nonexistent.txt"

        // Act & Assert - Should not throw
        try await sut.delete(path: path)
    }

    // MARK: - GenerateNumberedPath Tests

    func test_generateNumberedPath_shouldFormatCorrectly() {
        // Arrange
        let baseDir = "/path/to/project"

        // Act
        let path001 = sut.generateNumberedPath(baseDirectory: baseDir, number: 1, extension: "txt")
        let path010 = sut.generateNumberedPath(baseDirectory: baseDir, number: 10, extension: "wav")
        let path100 = sut.generateNumberedPath(baseDirectory: baseDir, number: 100, extension: "png")

        // Assert
        XCTAssertTrue(path001.contains("001"))
        XCTAssertTrue(path001.hasSuffix(".txt"))

        XCTAssertTrue(path010.contains("010"))
        XCTAssertTrue(path010.hasSuffix(".wav"))

        XCTAssertTrue(path100.contains("100"))
        XCTAssertTrue(path100.hasSuffix(".png"))
    }

    func test_generateNumberedPath_shouldIncludeBaseDirectory() {
        // Arrange
        let baseDir = "/documents/projects/MyProject"

        // Act
        let path = sut.generateNumberedPath(baseDirectory: baseDir, number: 5, extension: "txt")

        // Assert
        XCTAssertTrue(path.hasPrefix(baseDir))
    }

    func test_generateNumberedPath_withDifferentNumbers_shouldGenerateDifferentPaths() {
        // Arrange
        let baseDir = "/path"

        // Act
        let path1 = sut.generateNumberedPath(baseDirectory: baseDir, number: 1, extension: "txt")
        let path2 = sut.generateNumberedPath(baseDirectory: baseDir, number: 2, extension: "txt")
        let path3 = sut.generateNumberedPath(baseDirectory: baseDir, number: 3, extension: "txt")

        // Assert
        XCTAssertNotEqual(path1, path2)
        XCTAssertNotEqual(path2, path3)
    }

    // MARK: - Integration Tests

    func test_fullLifecycle_textFile() async throws {
        // Save
        let text = "Lifecycle test content"
        let path = "lifecycle.txt"
        try await sut.saveText(text, to: path)
        let existsAfterSave = await sut.exists(path: path)
        XCTAssertTrue(existsAfterSave)

        // Load
        let loadedText = try await sut.loadText(from: path)
        XCTAssertEqual(loadedText, text)

        // Delete
        try await sut.delete(path: path)
        let existsAfterDelete = await sut.exists(path: path)
        XCTAssertFalse(existsAfterDelete)
    }

    func test_fullLifecycle_binaryFile() async throws {
        // Save
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let path = "binary.dat"
        try await sut.save(data: data, to: path)
        let existsAfterSave = await sut.exists(path: path)
        XCTAssertTrue(existsAfterSave)

        // Load
        let loadedData = try await sut.load(from: path)
        XCTAssertEqual(loadedData, data)

        // Delete
        try await sut.delete(path: path)
        let existsAfterDelete = await sut.exists(path: path)
        XCTAssertFalse(existsAfterDelete)
    }

    func test_concurrentWrites_shouldNotCorruptFiles() async throws {
        // Arrange
        let files = (1...10).map { i in
            ("file_\(i).txt", "Content of file \(i)")
        }

        // Act - Write concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (path, content) in files {
                group.addTask {
                    try await self.sut.saveText(content, to: path)
                }
            }
            try await group.waitForAll()
        }

        // Assert - All files should exist with correct content
        for (path, expectedContent) in files {
            let fileExists = await sut.exists(path: path)
            XCTAssertTrue(fileExists)
            let loadedContent = try await sut.loadText(from: path)
            XCTAssertEqual(loadedContent, expectedContent)
        }
    }

    func test_largeTextFile_shouldHandleCorrectly() async throws {
        // Arrange - Create a large text (1MB)
        let largeText = String(repeating: "A", count: 1_000_000)
        let path = "large.txt"

        // Act
        try await sut.saveText(largeText, to: path)
        let loadedText = try await sut.loadText(from: path)

        // Assert
        XCTAssertEqual(loadedText.count, 1_000_000)
        XCTAssertEqual(loadedText, largeText)
    }
}
