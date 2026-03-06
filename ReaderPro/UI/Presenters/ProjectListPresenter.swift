import Foundation
import Combine
import AppKit

/// Presenter para la lista de proyectos
/// Coordina con Use Cases y actualiza el ViewModel
@MainActor
final class ProjectListPresenter: ObservableObject {

    // MARK: - Published Properties

    /// ViewModel que la View observa
    @Published private(set) var viewModel = ProjectListViewModel()

    // MARK: - Dependencies

    private let listProjectsUseCase: ListProjectsUseCaseProtocol
    private let deleteProjectUseCase: DeleteProjectUseCaseProtocol
    private let generateAudioUseCase: GenerateAudioUseCaseProtocol
    private let createProjectUseCase: CreateProjectUseCaseProtocol
    private let audioStorage: AudioStoragePort
    private let projectRepository: ProjectRepositoryPort
    private let createFolderUseCase: CreateFolderUseCaseProtocol
    private let listFoldersUseCase: ListFoldersUseCaseProtocol
    private let renameFolderUseCase: RenameFolderUseCaseProtocol
    private let deleteFolderUseCase: DeleteFolderUseCaseProtocol
    private let assignProjectToFolderUseCase: AssignProjectToFolderUseCaseProtocol

    // MARK: - Private Properties

    /// Caché de todos los proyectos (sin filtrar)
    private var allProjects: [ProjectSummary] = []

    /// Subscription para propagar cambios del viewModel anidado
    private var viewModelCancellable: AnyCancellable?

    // MARK: - Initialization

    init(
        listProjectsUseCase: ListProjectsUseCaseProtocol,
        deleteProjectUseCase: DeleteProjectUseCaseProtocol,
        generateAudioUseCase: GenerateAudioUseCaseProtocol,
        createProjectUseCase: CreateProjectUseCaseProtocol,
        audioStorage: AudioStoragePort,
        projectRepository: ProjectRepositoryPort,
        createFolderUseCase: CreateFolderUseCaseProtocol,
        listFoldersUseCase: ListFoldersUseCaseProtocol,
        renameFolderUseCase: RenameFolderUseCaseProtocol,
        deleteFolderUseCase: DeleteFolderUseCaseProtocol,
        assignProjectToFolderUseCase: AssignProjectToFolderUseCaseProtocol
    ) {
        self.listProjectsUseCase = listProjectsUseCase
        self.deleteProjectUseCase = deleteProjectUseCase
        self.generateAudioUseCase = generateAudioUseCase
        self.createProjectUseCase = createProjectUseCase
        self.audioStorage = audioStorage
        self.projectRepository = projectRepository
        self.createFolderUseCase = createFolderUseCase
        self.listFoldersUseCase = listFoldersUseCase
        self.renameFolderUseCase = renameFolderUseCase
        self.deleteFolderUseCase = deleteFolderUseCase
        self.assignProjectToFolderUseCase = assignProjectToFolderUseCase

        // Propagar cambios del viewModel anidado al presenter
        // Usa async para evitar "Publishing changes from within view updates"
        viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - View Lifecycle

    /// Llamado cuando la vista aparece
    /// Carga los proyectos
    func onAppear() async {
        await loadFolders()
        await loadProjects()
    }

    // MARK: - User Actions

    /// Elimina un proyecto
    /// - Parameter id: ID del proyecto a eliminar
    func deleteProject(id: Identifier<Project>) async {
        viewModel.isLoading = true
        viewModel.error = nil

        do {
            // 1. Eliminar proyecto
            let request = DeleteProjectRequest(projectId: id)
            _ = try await deleteProjectUseCase.execute(request)

            // 2. Recargar lista
            await loadProjects()

        } catch {
            viewModel.error = error.localizedDescription
            viewModel.isLoading = false
        }
    }

    /// Busca proyectos por query
    /// - Parameter query: Texto de búsqueda
    func search(query: String) async {
        viewModel.searchQuery = query
        applyFilters()
    }

    /// Crea un nuevo proyecto vacío con solo el nombre
    /// - Parameter name: Nombre del proyecto
    /// - Returns: ID del proyecto creado, o nil si falla
    @discardableResult
    func createProject(name: String, folderId: Identifier<Folder>? = nil) async -> Identifier<Project>? {
        viewModel.isLoading = true
        viewModel.error = nil

        do {
            // Use the provided folderId, or the active folder if viewing a specific folder
            let effectiveFolderId = folderId ?? activeFolderId
            let request = CreateProjectRequest(name: name, folderId: effectiveFolderId)
            let response = try await createProjectUseCase.execute(request)

            // 2. Recargar lista
            await loadProjects()

            return response.projectId

        } catch {
            viewModel.error = error.localizedDescription
            viewModel.isLoading = false
            return nil
        }
    }

    /// Genera audio para un proyecto
    /// - Parameter id: ID del proyecto
    /// - Returns: Duración del audio generado, o nil si falla
    func generateAudio(for id: Identifier<Project>) async throws -> TimeInterval {
        viewModel.isGeneratingAudio = true
        viewModel.generatingProjectId = id.value.uuidString
        viewModel.error = nil

        defer {
            viewModel.isGeneratingAudio = false
            viewModel.generatingProjectId = nil
        }

        let request = GenerateAudioRequest(projectId: id)
        let response = try await generateAudioUseCase.execute(request)

        // Recargar lista para reflejar el cambio
        await loadProjects()

        return response.duration
    }

    // MARK: - Private Methods

    /// Carga todos los proyectos desde el repositorio
    private func loadProjects() async {
        viewModel.isLoading = true
        viewModel.error = nil

        do {
            // 1. Ejecutar use case (ordenado por updatedAt descendente)
            let request = ListProjectsRequest(
                sortBy: .updatedAt,
                ascending: false
            )
            let response = try await listProjectsUseCase.execute(request)

            // 2. Guardar en caché
            allProjects = response.projects

            // 2.5. Resolver paths absolutos para thumbnails
            resolveThumbnailPaths(response.projects)

            // 3. Aplicar filtros (carpeta + búsqueda)
            applyFilters()

        } catch {
            viewModel.error = error.localizedDescription
            allProjects = []
            viewModel.projects = []
        }

        viewModel.isLoading = false
    }

    /// Resuelve los paths absolutos para los thumbnails de cada proyecto
    private func resolveThumbnailPaths(_ projects: [ProjectSummary]) {
        let baseDir = audioStorage.baseDirectory
        var paths: [String: String] = [:]
        for project in projects {
            if let thumbnailPath = project.thumbnailPath {
                let fullPath = (baseDir as NSString).appendingPathComponent(thumbnailPath)
                if FileManager.default.fileExists(atPath: fullPath) {
                    paths[project.id] = fullPath
                }
            }
        }
        viewModel.thumbnailFullPaths = paths
    }

    /// Establece una imagen de portada para un proyecto
    /// - Parameters:
    ///   - projectId: ID del proyecto
    ///   - imageURL: URL del archivo de imagen seleccionado
    func setCoverImage(for projectId: Identifier<Project>, imageURL: URL) async {
        do {
            // 1. Cargar el proyecto
            guard let project = try await projectRepository.findById(projectId) else { return }

            // 2. Copiar imagen al directorio del proyecto como cover.png
            let folderName = project.folderName ?? project.id.value.uuidString
            let projectDir = (audioStorage.baseDirectory as NSString)
                .appendingPathComponent(folderName)
            let coverPath = (projectDir as NSString).appendingPathComponent("cover.png")

            // Crear directorio si no existe
            try FileManager.default.createDirectory(
                atPath: projectDir,
                withIntermediateDirectories: true
            )

            // Copiar archivo (sobreescribir si existe)
            if FileManager.default.fileExists(atPath: coverPath) {
                try FileManager.default.removeItem(atPath: coverPath)
            }
            try FileManager.default.copyItem(
                atPath: imageURL.path,
                toPath: coverPath
            )

            // 3. Actualizar proyecto con path relativo
            let relativePath = (folderName as NSString).appendingPathComponent("cover.png")
            project.setCoverImage(path: relativePath)
            try await projectRepository.save(project)

            // 4. Recargar lista
            await loadProjects()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    /// Abre la carpeta del proyecto en Finder
    func showInFinder(project: ProjectSummary) {
        // Use stored folderName, fallback to sanitized name, then UUID for legacy projects.
        let folderName = project.folderName
            ?? FileSystemProjectRepository.sanitizeFolderName(project.name)
        let projectDir = (audioStorage.baseDirectory as NSString)
            .appendingPathComponent(folderName)
        // If the folder doesn't exist, try UUID fallback
        if FileManager.default.fileExists(atPath: projectDir) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectDir)
        } else {
            let uuidDir = (audioStorage.baseDirectory as NSString)
                .appendingPathComponent(project.projectId.value.uuidString)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: uuidDir)
        }
    }

    /// Verifica si un proyecto coincide con la query de búsqueda
    private func matchesSearchQuery(_ project: ProjectSummary, query: String) -> Bool {
        let lowercasedQuery = query.lowercased()

        if project.name.lowercased().contains(lowercasedQuery) {
            return true
        }

        if project.textPreview.lowercased().contains(lowercasedQuery) {
            return true
        }

        return false
    }

    /// Returns the active folder ID if a specific folder is selected
    private var activeFolderId: Identifier<Folder>? {
        if case .folder(let id) = viewModel.selectedFolder {
            return id
        }
        return nil
    }

    /// Applies both folder and search filters to allProjects
    private func applyFilters() {
        var filtered = allProjects

        // 1. Apply folder filter
        switch viewModel.selectedFolder {
        case .all:
            break // No filter
        case .uncategorized:
            filtered = filtered.filter { $0.folderId == nil }
        case .folder(let folderId):
            filtered = filtered.filter { $0.folderId == folderId }
        }

        // 2. Apply search filter
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            filtered = filtered.filter { matchesSearchQuery($0, query: trimmed) }
        }

        viewModel.projects = filtered
    }

    // MARK: - Folder Actions

    /// Carga las carpetas desde el repositorio
    func loadFolders() async {
        do {
            viewModel.folders = try await listFoldersUseCase.execute()
        } catch {
            print("[ProjectListPresenter] Error loading folders: \(error)")
        }
    }

    /// Crea una nueva carpeta
    func createFolder(name: String, colorHex: String = "#007AFF") async {
        do {
            _ = try await createFolderUseCase.execute(name: name, colorHex: colorHex)
            await loadFolders()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    /// Renombra una carpeta
    func renameFolder(id: Identifier<Folder>, newName: String) async {
        do {
            try await renameFolderUseCase.execute(folderId: id, newName: newName)
            await loadFolders()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    /// Elimina una carpeta (los proyectos quedan sin carpeta)
    func deleteFolder(id: Identifier<Folder>) async {
        // If we're viewing the deleted folder, go back to all
        if case .folder(let selectedId) = viewModel.selectedFolder, selectedId == id {
            viewModel.selectedFolder = .all
        }

        do {
            try await deleteFolderUseCase.execute(folderId: id)
            await loadFolders()
            await loadProjects()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    /// Selecciona una carpeta en el sidebar
    func selectFolder(_ selection: FolderSelection) {
        viewModel.selectedFolder = selection
        applyFilters()
    }

    /// Mueve un proyecto a una carpeta (o lo quita si folderId es nil)
    func moveProjectToFolder(projectId: Identifier<Project>, folderId: Identifier<Folder>?) async {
        do {
            try await assignProjectToFolderUseCase.execute(projectId: projectId, folderId: folderId)
            await loadFolders()
            await loadProjects()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }
}
