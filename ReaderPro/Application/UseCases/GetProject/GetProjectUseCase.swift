import Foundation

/// Use Case para obtener un proyecto existente por ID
/// Solo lectura, no modifica el proyecto
final class GetProjectUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort

    // MARK: - Initialization

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de obtención de proyecto
    /// - Parameter request: Request con el ID del proyecto
    /// - Returns: Response con los datos del proyecto
    /// - Throws: ApplicationError.projectNotFound si no existe
    func execute(_ request: GetProjectRequest) async throws -> GetProjectResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Mapear a DTO y retornar
        return GetProjectResponse(project: project)
    }
}
