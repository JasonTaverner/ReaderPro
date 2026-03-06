import XCTest
import AVFoundation
@testable import ReaderPro

/// Tests de integración para FileSystemAudioStorage
/// Usa directorio temporal y archivos de audio reales
final class FileSystemAudioStorageTests: XCTestCase {

    // MARK: - Properties

    var sut: FileSystemAudioStorage!
    var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        // Crear directorio temporal único para cada test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        sut = FileSystemAudioStorage(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        // Limpiar directorio temporal
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates a simple WAV file data (silence)
    private func createTestAudioData(duration: TimeInterval = 1.0) throws -> AudioData {
        // Create a simple WAV header + audio data
        // This is a minimal valid WAV file (silence)
        let sampleRate: Int = 44100
        let numSamples = Int(duration * Double(sampleRate))
        let numChannels: Int = 1
        let bitsPerSample: Int = 16

        let dataSize = numSamples * numChannels * (bitsPerSample / 8)
        let fileSize = 44 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })

        // Silence (zeros)
        wavData.append(Data(count: dataSize))

        return try AudioData(data: wavData, duration: duration)
    }

    // MARK: - Save Tests

    func test_save_withValidAudio_shouldReturnPath() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData(duration: 2.0)

        // Act
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Assert
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.hasSuffix(".wav"))
    }

    func test_save_shouldCreateFile() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()

        // Act
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Assert
        let fullPath = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_save_shouldIncludeFolderNameInPath() async throws {
        // Arrange
        let audioData = try createTestAudioData()

        // Act
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Assert
        XCTAssertTrue(path.contains("TestProject"))
        XCTAssertTrue(path.hasSuffix(".wav"))
    }

    func test_save_multipleTimes_shouldCreateMultipleFiles() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData1 = try createTestAudioData(duration: 1.0)
        let audioData2 = try createTestAudioData(duration: 2.0)
        let audioData3 = try createTestAudioData(duration: 3.0)

        // Act
        let path1 = try await sut.save(audioData: audioData1, folderName: "TestProject", entryNumber: 1)
        let path2 = try await sut.save(audioData: audioData2, folderName: "TestProject", entryNumber: 2)
        let path3 = try await sut.save(audioData: audioData3, folderName: "TestProject", entryNumber: 3)

        // Assert
        XCTAssertNotEqual(path1, path2)
        XCTAssertNotEqual(path2, path3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent(path1).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent(path2).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent(path3).path))
    }

    // MARK: - Load Tests

    func test_load_withExistingFile_shouldReturnAudioData() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let originalAudio = try createTestAudioData(duration: 3.0)
        let path = try await sut.save(audioData: originalAudio, folderName: "TestProject", entryNumber: nil)

        // Act
        let loadedAudio = try await sut.load(path: path)

        // Assert
        XCTAssertNotNil(loadedAudio)
        XCTAssertEqual(loadedAudio.data.count, originalAudio.data.count)
        XCTAssertGreaterThan(loadedAudio.duration, 0)
    }

    func test_load_withNonexistentFile_shouldThrowError() async throws {
        // Arrange
        let nonexistentPath = "nonexistent.wav"

        // Act & Assert
        do {
            _ = try await sut.load(path: nonexistentPath)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    func test_load_shouldReturnCorrectDuration() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let expectedDuration: TimeInterval = 5.0
        let audioData = try createTestAudioData(duration: expectedDuration)
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Act
        let loadedAudio = try await sut.load(path: path)

        // Assert
        XCTAssertEqual(loadedAudio.duration, expectedDuration, accuracy: 0.1)
    }

    // MARK: - Delete Tests

    func test_delete_withExistingFile_shouldRemoveFile() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        let fullPath = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))

        // Act
        try await sut.delete(path: path)

        // Assert
        XCTAssertFalse(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_delete_withNonexistentFile_shouldNotThrow() async throws {
        // Arrange
        let nonexistentPath = "nonexistent.wav"

        // Act & Assert - Should not throw
        try await sut.delete(path: nonexistentPath)
    }

    // MARK: - Exists Tests

    func test_exists_withExistingFile_shouldReturnTrue() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Act
        let exists = await sut.exists(path: path)

        // Assert
        XCTAssertTrue(exists)
    }

    func test_exists_withNonexistentFile_shouldReturnFalse() async {
        // Arrange
        let nonexistentPath = "nonexistent.wav"

        // Act
        let exists = await sut.exists(path: nonexistentPath)

        // Assert
        XCTAssertFalse(exists)
    }

    func test_exists_afterDelete_shouldReturnFalse() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        let exists_path = await sut.exists(path: path)
        XCTAssertTrue(exists_path)

        // Act
        try await sut.delete(path: path)

        // Assert
        let exists = await sut.exists(path: path)
        XCTAssertFalse(exists)
    }

    // MARK: - GetSize Tests

    func test_getSize_withExistingFile_shouldReturnSize() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData(duration: 1.0)
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Act
        let size = try await sut.getSize(path: path)

        // Assert
        XCTAssertGreaterThan(size, 0)
        // WAV file size should be approximately the data size
        XCTAssertEqual(size, audioData.sizeInBytes, accuracy: 1000)
    }

    func test_getSize_withNonexistentFile_shouldThrowError() async {
        // Arrange
        let nonexistentPath = "nonexistent.wav"

        // Act & Assert
        do {
            _ = try await sut.getSize(path: nonexistentPath)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    // MARK: - Copy Tests

    func test_copy_shouldCreateDuplicateFile() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let sourcePath = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)
        let destPath = "copy_\(UUID().uuidString).wav"

        // Act
        try await sut.copy(from: sourcePath, to: destPath)

        // Assert
        let exists_sourcePath = await sut.exists(path: sourcePath)
        XCTAssertTrue(exists_sourcePath)
        let exists_destPath = await sut.exists(path: destPath)
        XCTAssertTrue(exists_destPath)

        // Both files should have same size
        let sourceSize = try await sut.getSize(path: sourcePath)
        let destSize = try await sut.getSize(path: destPath)
        XCTAssertEqual(sourceSize, destSize)
    }

    func test_copy_withNonexistentSource_shouldThrowError() async {
        // Arrange
        let sourcePath = "nonexistent.wav"
        let destPath = "dest.wav"

        // Act & Assert
        do {
            try await sut.copy(from: sourcePath, to: destPath)
            XCTFail("Should throw error for nonexistent source")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    // MARK: - Move Tests

    func test_move_shouldRelocateFile() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let sourcePath = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)
        let destPath = "moved_\(UUID().uuidString).wav"

        let exists_sourcePath = await sut.exists(path: sourcePath)
        XCTAssertTrue(exists_sourcePath)

        // Act
        try await sut.move(from: sourcePath, to: destPath)

        // Assert
        let existsAfter_sourcePath = await sut.exists(path: sourcePath)
        XCTAssertFalse(existsAfter_sourcePath)
        let exists_destPath = await sut.exists(path: destPath)
        XCTAssertTrue(exists_destPath)
    }

    func test_move_withNonexistentSource_shouldThrowError() async {
        // Arrange
        let sourcePath = "nonexistent.wav"
        let destPath = "dest.wav"

        // Act & Assert
        do {
            try await sut.move(from: sourcePath, to: destPath)
            XCTFail("Should throw error for nonexistent source")
        } catch {
            XCTAssertTrue(error is InfrastructureError)
        }
    }

    // MARK: - BaseDirectory Tests

    func test_baseDirectory_shouldReturnConfiguredPath() {
        // Assert
        XCTAssertEqual(sut.baseDirectory, tempDirectory.path)
    }

    // MARK: - GenerateUniquePath Tests

    func test_generateUniquePath_shouldIncludeFolderName() async {
        // Act
        let path = await sut.generateUniquePath(folderName: "TestProject", format: .wav)

        // Assert
        XCTAssertTrue(path.contains("TestProject"))
        XCTAssertTrue(path.hasSuffix(".wav"))
    }

    func test_generateUniquePath_shouldBeSequential() async throws {
        // Arrange - save two files first so the directory has existing files
        let audioData = try createTestAudioData()
        _ = try await sut.save(audioData: audioData, folderName: "SeqTest", entryNumber: 1)
        _ = try await sut.save(audioData: audioData, folderName: "SeqTest", entryNumber: 2)

        // Act
        let path = await sut.generateUniquePath(folderName: "SeqTest", format: .wav)

        // Assert - should be 003.wav since 001 and 002 exist
        XCTAssertEqual(path, "SeqTest/003.wav")
    }

    func test_generateUniquePath_shouldRespectFormat() async {
        // Act
        let wavPath = await sut.generateUniquePath(folderName: "TestProject", format: .wav)
        let mp3Path = await sut.generateUniquePath(folderName: "TestProject", format: .mp3)
        let m4aPath = await sut.generateUniquePath(folderName: "TestProject", format: .m4a)

        // Assert
        XCTAssertTrue(wavPath.hasSuffix(".wav"))
        XCTAssertTrue(mp3Path.hasSuffix(".mp3"))
        XCTAssertTrue(m4aPath.hasSuffix(".m4a"))
    }

    // MARK: - Export Tests (Basic)

    func test_export_shouldReturnData() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData()
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)

        // Act
        let exportedData = try await sut.export(path: path, format: .wav, quality: .high)

        // Assert
        XCTAssertFalse(exportedData.isEmpty)
    }

    // MARK: - Integration Tests

    func test_fullLifecycle_saveLoadDelete() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioData = try createTestAudioData(duration: 2.5)

        // Save
        let path = try await sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)
        let exists_path = await sut.exists(path: path)
        XCTAssertTrue(exists_path)

        // Load
        let loadedAudio = try await sut.load(path: path)
        XCTAssertEqual(loadedAudio.duration, 2.5, accuracy: 0.1)

        // Get size
        let size = try await sut.getSize(path: path)
        XCTAssertGreaterThan(size, 0)

        // Delete
        try await sut.delete(path: path)
        let existsAfter_path = await sut.exists(path: path)
        XCTAssertFalse(existsAfter_path)
    }

    func test_concurrentSaves_shouldNotCorruptFiles() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        let audioFiles = try (1...10).map { i in
            try createTestAudioData(duration: Double(i))
        }

        // Act - Save concurrently (each with nil entryNumber so they auto-detect)
        let paths = try await withThrowingTaskGroup(of: String.self) { group in
            for audioData in audioFiles {
                group.addTask {
                    try await self.sut.save(audioData: audioData, folderName: "TestProject", entryNumber: nil)
                }
            }

            var results: [String] = []
            for try await path in group {
                results.append(path)
            }
            return results
        }

        // Assert
        XCTAssertEqual(paths.count, 10)
        XCTAssertEqual(Set(paths).count, 10) // All paths should be unique

        // All files should exist
        for path in paths {
            let exists_path = await sut.exists(path: path)
        XCTAssertTrue(exists_path)
        }
    }
}
