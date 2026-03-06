import Foundation
@testable import ReaderPro

/// Mock del AudioStoragePort para tests
/// Simula almacenamiento de archivos de audio
final class MockAudioStoragePort: AudioStoragePort {

    // MARK: - Call Tracking

    var saveCalled = false
    var saveCallCount = 0
    var loadCalled = false
    var deleteCalled = false
    var exportCalled = false
    var copyCalled = false
    var moveCalled = false
    var existsCalled = false
    var getSizeCalled = false
    var generateUniquePathCalled = false

    var lastSavedAudioData: AudioData?
    var lastSavedFolderName: String?
    var lastSavedEntryNumber: Int?
    var lastLoadedPath: String?
    var lastDeletedPath: String?
    var lastExportedPath: String?
    var lastExportFormat: AudioFormat?
    var lastExportQuality: AudioQuality?
    var lastCopySource: String?
    var lastCopyDestination: String?
    var lastMoveSource: String?
    var lastMoveDestination: String?
    var lastExistsPath: String?
    var lastGetSizePath: String?
    var lastGeneratePathFolderName: String?
    var lastGeneratePathFormat: AudioFormat?

    // MARK: - Stub Responses

    var pathToReturn: String = "/audio/generated.wav"
    var audioDataToReturn: AudioData?
    var dataToReturn: Data = Data()
    var existsValue: Bool = true
    var sizeValue: Int = 1024
    var errorToThrow: Error?

    // MARK: - AudioStoragePort Implementation

    func save(audioData: AudioData, folderName: String, entryNumber: Int?) async throws -> String {
        saveCalled = true
        saveCallCount += 1
        lastSavedAudioData = audioData
        lastSavedFolderName = folderName
        lastSavedEntryNumber = entryNumber

        if let error = errorToThrow {
            throw error
        }

        return pathToReturn
    }

    func load(path: String) async throws -> AudioData {
        loadCalled = true
        lastLoadedPath = path

        if let error = errorToThrow {
            throw error
        }

        guard let audioData = audioDataToReturn else {
            // Return default audio data
            let defaultData = Data(repeating: 0, count: 1024)
            return try! AudioData(data: defaultData, duration: 10.0)
        }

        return audioData
    }

    func delete(path: String) async throws {
        deleteCalled = true
        lastDeletedPath = path

        if let error = errorToThrow {
            throw error
        }
    }

    func export(path: String, format: AudioFormat, quality: AudioQuality) async throws -> Data {
        exportCalled = true
        lastExportedPath = path
        lastExportFormat = format
        lastExportQuality = quality

        if let error = errorToThrow {
            throw error
        }

        return dataToReturn
    }

    func copy(from sourcePath: String, to destinationPath: String) async throws {
        copyCalled = true
        lastCopySource = sourcePath
        lastCopyDestination = destinationPath

        if let error = errorToThrow {
            throw error
        }
    }

    func move(from sourcePath: String, to destinationPath: String) async throws {
        moveCalled = true
        lastMoveSource = sourcePath
        lastMoveDestination = destinationPath

        if let error = errorToThrow {
            throw error
        }
    }

    func exists(path: String) async -> Bool {
        existsCalled = true
        lastExistsPath = path
        return existsValue
    }

    func getSize(path: String) async throws -> Int {
        getSizeCalled = true
        lastGetSizePath = path

        if let error = errorToThrow {
            throw error
        }

        return sizeValue
    }

    var baseDirectory: String {
        "/Users/test/Documents/ReaderPro/Audio"
    }

    func generateUniquePath(folderName: String, format: AudioFormat) async -> String {
        generateUniquePathCalled = true
        lastGeneratePathFolderName = folderName
        lastGeneratePathFormat = format
        return pathToReturn
    }

    // MARK: - Helper Methods

    func reset() {
        saveCalled = false
        saveCallCount = 0
        loadCalled = false
        deleteCalled = false
        exportCalled = false
        copyCalled = false
        moveCalled = false
        existsCalled = false
        getSizeCalled = false
        generateUniquePathCalled = false

        lastSavedAudioData = nil
        lastSavedFolderName = nil
        lastSavedEntryNumber = nil
        lastLoadedPath = nil
        lastDeletedPath = nil
        lastExportedPath = nil
        lastExportFormat = nil
        lastExportQuality = nil
        lastCopySource = nil
        lastCopyDestination = nil
        lastMoveSource = nil
        lastMoveDestination = nil
        lastExistsPath = nil
        lastGetSizePath = nil
        lastGeneratePathFolderName = nil
        lastGeneratePathFormat = nil

        pathToReturn = "/audio/generated.wav"
        audioDataToReturn = nil
        dataToReturn = Data()
        existsValue = true
        sizeValue = 1024
        errorToThrow = nil
    }
}
