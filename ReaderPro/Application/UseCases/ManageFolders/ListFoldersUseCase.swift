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
        let t0 = CFAbsoluteTimeGetCurrent()
        let folders = try await folderRepository.findAll()
        let t1 = CFAbsoluteTimeGetCurrent()
        let projects = try await projectRepository.findAll()
        let t2 = CFAbsoluteTimeGetCurrent()
        if t2 - t0 > 0.5 {
            print(String(format: "[Perf] ListFolders: folderRepo %.2fs, projectRepo %.2fs",
                         t1 - t0, t2 - t1))
        }

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
