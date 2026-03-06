import Foundation

/// Use Case para crear una nueva carpeta
final class CreateFolderUseCase: CreateFolderUseCaseProtocol {

    private let folderRepository: FolderRepositoryPort

    init(folderRepository: FolderRepositoryPort) {
        self.folderRepository = folderRepository
    }

    func execute(name: String, colorHex: String) async throws -> Identifier<Folder> {
        let folderName = try FolderName(name)

        // Determine sort order: append at end
        let existing = try await folderRepository.findAll()
        let maxOrder = existing.map(\.sortOrder).max() ?? -1

        let folder = Folder(
            name: folderName,
            colorHex: colorHex,
            sortOrder: maxOrder + 1
        )

        try await folderRepository.save(folder)
        return folder.id
    }
}
