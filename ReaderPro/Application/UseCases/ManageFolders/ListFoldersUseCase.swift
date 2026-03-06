import Foundation

/// Use Case para listar carpetas con conteo de proyectos
final class ListFoldersUseCase: ListFoldersUseCaseProtocol {

    private let folderRepository: FolderRepositoryPort
    private let projectRepository: ProjectRepositoryPort

    init(folderRepository: FolderRepositoryPort, projectRepository: ProjectRepositoryPort) {
        self.folderRepository = folderRepository
        self.projectRepository = projectRepository
    }

    func execute() async throws -> [FolderSummary] {
        let folders = try await folderRepository.findAll()
        let projects = try await projectRepository.findAll()

        return folders.map { folder in
            let count = projects.filter { $0.folderId == folder.id }.count
            return FolderSummary(
                folderId: folder.id,
                name: folder.name.value,
                colorHex: folder.colorHex,
                sortOrder: folder.sortOrder,
                projectCount: count
            )
        }
    }
}
