import Foundation

/// Port para el repositorio de proyectos
/// Define la interfaz de persistencia que deben implementar los adaptadores
/// (SwiftDataProjectRepository, CoreDataRepository, etc.)
protocol ProjectRepositoryPort {
    /// Guarda un proyecto (create o update)
    /// - Parameter project: El proyecto a guardar
    /// - Throws: Error si falla la persistencia
    func save(_ project: Project) async throws

    /// Busca un proyecto por su ID
    /// - Parameter id: El ID del proyecto
    /// - Returns: El proyecto si existe, nil si no
    /// - Throws: Error si falla la consulta
    func findById(_ id: Identifier<Project>) async throws -> Project?

    /// Obtiene todos los proyectos
    /// - Returns: Lista de todos los proyectos
    /// - Throws: Error si falla la consulta
    func findAll() async throws -> [Project]

    /// Busca proyectos que coincidan con el query
    /// - Parameter query: Texto de búsqueda (busca en nombre y texto)
    /// - Returns: Lista de proyectos que coinciden
    /// - Throws: Error si falla la búsqueda
    func search(query: String) async throws -> [Project]

    /// Elimina un proyecto
    /// - Parameter id: El ID del proyecto a eliminar
    /// - Throws: Error si falla la eliminación o el proyecto no existe
    func delete(_ id: Identifier<Project>) async throws

    /// Obtiene proyectos filtrados por estado
    /// - Parameter status: El estado a filtrar
    /// - Returns: Lista de proyectos con ese estado
    /// - Throws: Error si falla la consulta
    func findByStatus(_ status: ProjectStatus) async throws -> [Project]

    /// Obtiene proyectos creados después de una fecha
    /// - Parameter date: La fecha límite
    /// - Returns: Lista de proyectos creados después de esa fecha
    /// - Throws: Error si falla la consulta
    func findCreatedAfter(_ date: Date) async throws -> [Project]
}
