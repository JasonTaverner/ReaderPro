import Foundation

/// Use Case para eliminar una carpeta
/// Los proyectos que pertenecían a la carpeta pasan a sin carpeta (folderId = nil)
final class DeleteFolderUseCase: DeleteFolderUseCaseProtocol {

    private let folderRepository: FolderRepositoryPort
    private let projectRepository: ProjectRepositoryPort

    init(folderRepository: FolderRepositoryPort, projectRepository: ProjectRepositoryPort) {
        self.folderRepository = folderRepository
        self.projectRepository = projectRepository
    }

    func execute(folderId: Identifier<Folder>) async throws {
        // Unassign all projects from this folder
        let projects = try await projectRepository.findAll()
        for project in projects where project.folderId == folderId {
            project.assignToFolder(nil)
            try await projectRepository.save(project)
        }

        // Delete the folder
        try await folderRepository.delete(folderId)
    }
}
