import Foundation

/// Use Case para asignar o desasignar un proyecto a una carpeta
final class AssignProjectToFolderUseCase: AssignProjectToFolderUseCaseProtocol {

    private let projectRepository: ProjectRepositoryPort

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    /// Asigna un proyecto a una carpeta, o lo desasigna si folderId es nil
    func execute(projectId: Identifier<Project>, folderId: Identifier<Folder>?) async throws {
        guard let project = try await projectRepository.findById(projectId) else {
            throw DomainError.projectNotFound
        }

        project.assignToFolder(folderId)
        try await projectRepository.save(project)
    }
}
