import Foundation

/// Use Case para eliminar un proyecto existente
/// Elimina el proyecto y sus archivos de audio asociados
final class DeleteProjectUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort
    private let audioStorage: AudioStoragePort

    // MARK: - Initialization

    init(
        projectRepository: ProjectRepositoryPort,
        audioStorage: AudioStoragePort
    ) {
        self.projectRepository = projectRepository
        self.audioStorage = audioStorage
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de eliminación de proyecto
    /// - Parameter request: Request con el ID del proyecto a eliminar
    /// - Returns: Response con información de la eliminación
    /// - Throws: ApplicationError.projectNotFound si no existe
    func execute(_ request: DeleteProjectRequest) async throws -> DeleteProjectResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Guardar datos para response (antes de eliminar)
        let projectName = project.name.value
        let audioPath = project.audioPath

        // 3. Eliminar archivo de audio si existe (best effort)
        var audioDeleted = false
        if let audioPath = audioPath, !audioPath.isEmpty {
            do {
                try await audioStorage.delete(path: audioPath)
                audioDeleted = true
            } catch {
                // Log error but continue with project deletion
                // Audio deletion is best-effort
                audioDeleted = false
            }
        }

        // 4. Eliminar proyecto del repositorio
        try await projectRepository.delete(request.projectId)

        // 5. Retornar response
        return DeleteProjectResponse(
            projectId: request.projectId,
            projectName: projectName,
            deleted: true,
            audioDeleted: audioDeleted
        )
    }
}
