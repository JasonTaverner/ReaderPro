import Foundation

/// ViewModel para ProjectListView
/// Solo contiene estado de UI - sin lógica de negocio
@MainActor
final class ProjectListViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Lista de proyectos a mostrar
    @Published var projects: [ProjectSummary] = []

    /// Indica si está cargando datos
    @Published var isLoading: Bool = false

    /// Mensaje de error, nil si no hay error
    @Published var error: String?

    /// Query de búsqueda actual
    @Published var searchQuery: String = ""

    /// Indica si está generando audio
    @Published var isGeneratingAudio: Bool = false

    /// ID del proyecto que está generando audio
    @Published var generatingProjectId: String?

    /// Mapeo projectId → full path de thumbnail
    @Published var thumbnailFullPaths: [String: String] = [:]

    // MARK: - Folder State

    /// Lista de carpetas disponibles
    @Published var folders: [FolderSummary] = []

    /// Carpeta seleccionada actualmente en el sidebar
    @Published var selectedFolder: FolderSelection = .all

    /// Indica si se está creando una nueva carpeta
    @Published var isCreatingFolder: Bool = false

    /// Nombre de la nueva carpeta que se está creando
    @Published var newFolderName: String = ""

    /// Indica si hay proyectos
    var hasProjects: Bool {
        !projects.isEmpty
    }

    /// Indica si debe mostrar el estado vacío
    var showEmptyState: Bool {
        !isLoading && projects.isEmpty && searchQuery.isEmpty
    }

    /// Indica si debe mostrar "sin resultados"
    var showNoResults: Bool {
        !isLoading && projects.isEmpty && !searchQuery.isEmpty
    }
}

/// Representa la selección actual de carpeta en el sidebar
enum FolderSelection: Hashable {
    case all
    case uncategorized
    case folder(Identifier<Folder>)
}
