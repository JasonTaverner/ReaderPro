import Foundation
@testable import ReaderPro

/// Mocks de los use cases de carpetas para testing

final class MockCreateFolderUseCase: CreateFolderUseCaseProtocol {
    var executeCalled = false
    var folderIdToReturn = Identifier<Folder>(UUID())
    var errorToThrow: Error?

    func execute(name: String, colorHex: String) async throws -> Identifier<Folder> {
        executeCalled = true
        if let error = errorToThrow { throw error }
        return folderIdToReturn
    }
}

final class MockListFoldersUseCase: ListFoldersUseCaseProtocol {
    var executeCalled = false
    var foldersToReturn: [FolderSummary] = []
    var errorToThrow: Error?

    func execute() async throws -> [FolderSummary] {
        executeCalled = true
        if let error = errorToThrow { throw error }
        return foldersToReturn
    }
}

final class MockRenameFolderUseCase: RenameFolderUseCaseProtocol {
    var executeCalled = false
    var errorToThrow: Error?

    func execute(folderId: Identifier<Folder>, newName: String) async throws {
        executeCalled = true
        if let error = errorToThrow { throw error }
    }
}

final class MockDeleteFolderUseCase: DeleteFolderUseCaseProtocol {
    var executeCalled = false
    var errorToThrow: Error?

    func execute(folderId: Identifier<Folder>) async throws {
        executeCalled = true
        if let error = errorToThrow { throw error }
    }
}

final class MockAssignProjectToFolderUseCase: AssignProjectToFolderUseCaseProtocol {
    var executeCalled = false
    var errorToThrow: Error?

    func execute(projectId: Identifier<Project>, folderId: Identifier<Folder>?) async throws {
        executeCalled = true
        if let error = errorToThrow { throw error }
    }
}
