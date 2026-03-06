import Foundation

/// Use Case para renombrar una carpeta
final class RenameFolderUseCase: RenameFolderUseCaseProtocol {

    private let folderRepository: FolderRepositoryPort

    init(folderRepository: FolderRepositoryPort) {
        self.folderRepository = folderRepository
    }

    func execute(folderId: Identifier<Folder>, newName: String) async throws {
        guard let folder = try await folderRepository.findById(folderId) else {
            throw DomainError.projectNotFound
        }

        let name = try FolderName(newName)
        folder.rename(name)
        try await folderRepository.save(folder)
    }
}
