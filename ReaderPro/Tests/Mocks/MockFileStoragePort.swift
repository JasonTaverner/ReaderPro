import Foundation
@testable import ReaderPro

/// Mock del FileStoragePort para tests
final class MockFileStoragePort: FileStoragePort {

    // MARK: - Call Tracking

    var saveCalled = false
    var saveTextCalled = false
    var loadTextCalled = false
    var loadCalled = false
    var existsCalled = false
    var deleteCalled = false
    var generateNumberedPathCalled = false
    var createDirectoryCalled = false

    var lastSavedData: Data?
    var lastSavedPath: String?
    var lastSavedText: String?
    var lastSavedTextPath: String?
    var lastLoadedPath: String?
    var lastLoadedTextPath: String?
    var lastExistsPath: String?
    var lastDeletedPath: String?
    var lastGeneratedBaseDirectory: String?
    var lastGeneratedNumber: Int?
    var lastGeneratedExtension: String?

    // MARK: - Stub Responses

    var textToReturn: String = ""
    var dataToReturn: Data = Data()
    var existsValue: Bool = true
    var pathToGenerate: String = "/path/to/file"
    var errorToThrow: Error?

    // MARK: - FileStoragePort Implementation

    func save(data: Data, to path: String) async throws {
        saveCalled = true
        lastSavedData = data
        lastSavedPath = path

        if let error = errorToThrow {
            throw error
        }
    }

    func saveText(_ text: String, to path: String) async throws {
        saveTextCalled = true
        lastSavedText = text
        lastSavedTextPath = path

        if let error = errorToThrow {
            throw error
        }
    }

    func loadText(from path: String) async throws -> String {
        loadTextCalled = true
        lastLoadedTextPath = path

        if let error = errorToThrow {
            throw error
        }

        return textToReturn
    }

    func load(from path: String) async throws -> Data {
        loadCalled = true
        lastLoadedPath = path

        if let error = errorToThrow {
            throw error
        }

        return dataToReturn
    }

    func exists(path: String) async -> Bool {
        existsCalled = true
        lastExistsPath = path
        return existsValue
    }

    func delete(path: String) async throws {
        deleteCalled = true
        lastDeletedPath = path

        if let error = errorToThrow {
            throw error
        }
    }

    func generateNumberedPath(
        baseDirectory: String,
        number: Int,
        extension: String
    ) -> String {
        generateNumberedPathCalled = true
        lastGeneratedBaseDirectory = baseDirectory
        lastGeneratedNumber = number
        lastGeneratedExtension = `extension`

        return pathToGenerate
    }

    func createDirectory(at path: String) async throws {
        createDirectoryCalled = true
        if let error = errorToThrow {
            throw error
        }
    }

    // MARK: - Helper Methods

    func reset() {
        saveCalled = false
        saveTextCalled = false
        loadTextCalled = false
        loadCalled = false
        existsCalled = false
        deleteCalled = false
        generateNumberedPathCalled = false
        createDirectoryCalled = false

        lastSavedData = nil
        lastSavedPath = nil
        lastSavedText = nil
        lastSavedTextPath = nil
        lastLoadedPath = nil
        lastLoadedTextPath = nil
        lastExistsPath = nil
        lastDeletedPath = nil
        lastGeneratedBaseDirectory = nil
        lastGeneratedNumber = nil
        lastGeneratedExtension = nil

        textToReturn = ""
        dataToReturn = Data()
        existsValue = true
        pathToGenerate = "/path/to/file"
        errorToThrow = nil
    }
}
