import Foundation

/// Request DTO para listar proyectos
struct ListProjectsRequest {
    let sortBy: SortOption
    let ascending: Bool

    /// Opciones de ordenamiento para la lista de proyectos
    enum SortOption {
        case createdAt
        case updatedAt
        case name
        case status
    }

    init(sortBy: SortOption = .updatedAt, ascending: Bool = false) {
        self.sortBy = sortBy
        self.ascending = ascending
    }
}
