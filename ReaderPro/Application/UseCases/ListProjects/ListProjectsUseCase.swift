import Foundation

/// Use Case para listar todos los proyectos
/// Retorna una lista ordenada de resúmenes de proyectos
final class ListProjectsUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort

    // MARK: - Initialization

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de listado de proyectos
    /// - Parameter request: Request con opciones de ordenamiento
    /// - Returns: Response con la lista de proyectos
    /// - Throws: Errores del repositorio
    func execute(_ request: ListProjectsRequest) async throws -> ListProjectsResponse {
        // 1. Obtener todos los proyectos
        var projects = try await projectRepository.findAll()

        // 2. Ordenar según el request
        projects = sortProjects(projects, by: request.sortBy, ascending: request.ascending)

        // 3. Mapear a ProjectSummary
        let summaries = projects.map { project in
            mapToSummary(project)
        }

        // 4. Retornar response
        return ListProjectsResponse(projects: summaries)
    }

    // MARK: - Private Helpers

    /// Ordena los proyectos según el criterio especificado
    private func sortProjects(
        _ projects: [Project],
        by sortOption: ListProjectsRequest.SortOption,
        ascending: Bool
    ) -> [Project] {
        let sorted: [Project]

        switch sortOption {
        case .createdAt:
            sorted = projects.sorted { ascending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }

        case .updatedAt:
            sorted = projects.sorted { ascending ? $0.updatedAt < $1.updatedAt : $0.updatedAt > $1.updatedAt }

        case .name:
            sorted = projects.sorted { ascending ? $0.name.value < $1.name.value : $0.name.value > $1.name.value }

        case .status:
            sorted = projects.sorted { ascending ? $0.status.rawValue < $1.status.rawValue : $0.status.rawValue > $1.status.rawValue }
        }

        return sorted
    }

    /// Mapea un Project a ProjectSummary
    private func mapToSummary(_ project: Project) -> ProjectSummary {
        // Truncar texto para preview (primeros 100 caracteres)
        let textPreview = truncateText(project.text?.value ?? "", maxLength: 100)

        return ProjectSummary(
            projectId: project.id,
            name: project.name.value,
            textPreview: textPreview,
            status: project.status,
            hasAudio: project.hasAudio,
            voiceName: project.voice.name,
            voiceProvider: project.voice.provider,
            thumbnailPath: project.thumbnailImagePath,
            folderName: project.folderName,
            folderId: project.folderId,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
        )
    }

    /// Trunca el texto a una longitud máxima
    private func truncateText(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }

        let truncated = String(text.prefix(maxLength))
        return truncated + "..."
    }
}
