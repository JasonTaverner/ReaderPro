import Foundation

/// Aggregate Root que representa un proyecto completo de audio
/// Coordina el texto, voz, audio generado y entradas asociadas
/// - Contiene entidades AudioEntry
/// - Protege invariantes del dominio
/// - Emite eventos de dominio
/// - Mutable class con comportamiento controlado
final class Project {
    typealias ProjectId = Identifier<Project>

    // MARK: - Properties

    private(set) var id: ProjectId
    private(set) var name: ProjectName
    private(set) var text: TextContent?
    private(set) var voiceConfiguration: VoiceConfiguration
    private(set) var voice: Voice
    private(set) var audioPath: String?
    private(set) var status: ProjectStatus
    private(set) var entries: [AudioEntry]
    private(set) var coverImagePath: String?
    private(set) var folderId: Identifier<Folder>?
    /// Nombre real de la carpeta en disco (sanitizado del nombre del proyecto)
    private(set) var folderName: String?
    private(set) var createdAt: Date
    private(set) var updatedAt: Date

    // Domain Events
    private(set) var domainEvents: [DomainEvent] = []

    // MARK: - Initializers

    /// Crea un nuevo proyecto (generación de ID automática)
    /// - Parameters:
    ///   - name: Nombre del proyecto
    ///   - text: Texto a convertir en audio (opcional para proyectos vacíos)
    ///   - voiceConfiguration: Configuración de voz (velocidad, etc.)
    ///   - voice: Voz a utilizar para la generación
    init(
        name: ProjectName,
        text: TextContent? = nil,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice,
        folderId: Identifier<Folder>? = nil
    ) {
        self.id = ProjectId()
        self.name = name
        self.text = text
        self.voiceConfiguration = voiceConfiguration
        self.voice = voice
        self.audioPath = nil
        self.status = .draft
        self.entries = []
        self.coverImagePath = nil
        self.folderId = folderId
        self.createdAt = Date()
        self.updatedAt = Date()

        addEvent(ProjectCreatedEvent(projectId: id, name: name))
    }

    /// Reconstitución desde persistencia
    /// - Parameters:
    ///   - id: ID existente
    ///   - name: Nombre del proyecto
    ///   - text: Texto del proyecto (opcional)
    ///   - voiceConfiguration: Configuración de voz
    ///   - voice: Voz utilizada
    ///   - audioPath: Path al audio generado (opcional)
    ///   - status: Estado del proyecto
    ///   - entries: Entradas asociadas
    ///   - createdAt: Fecha de creación
    ///   - updatedAt: Fecha de última actualización
    init(
        id: ProjectId,
        name: ProjectName,
        text: TextContent?,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice,
        audioPath: String?,
        status: ProjectStatus,
        entries: [AudioEntry],
        coverImagePath: String? = nil,
        folderId: Identifier<Folder>? = nil,
        folderName: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.voiceConfiguration = voiceConfiguration
        self.voice = voice
        self.audioPath = audioPath
        self.status = status
        self.entries = entries
        self.coverImagePath = coverImagePath
        self.folderId = folderId
        self.folderName = folderName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        // No emite eventos en reconstitución
    }

    // MARK: - Computed Properties

    /// Indica si el proyecto tiene texto
    var hasText: Bool {
        text != nil && !(text?.value.isEmpty ?? true)
    }

    /// Indica si el proyecto tiene audio generado
    var hasAudio: Bool {
        audioPath != nil
    }

    /// Indica si el proyecto puede regenerar audio (no está generando actualmente)
    var canRegenerate: Bool {
        status != .generating
    }

    /// Indica si el proyecto puede generar audio (tiene texto y no está generando)
    var canGenerateAudio: Bool {
        hasText && status != .generating
    }

    /// Path al thumbnail del proyecto: cover image o primera imagen de entries
    var thumbnailImagePath: String? {
        coverImagePath ?? entries.first(where: { $0.imagePath != nil })?.imagePath
    }

    // MARK: - Folder Name Mutation

    /// Actualiza el nombre de la carpeta en disco
    func updateFolderName(_ newFolderName: String) {
        self.folderName = newFolderName
    }

    /// Actualiza los paths de todas las entries al cambiar de carpeta
    func rewritePaths(from oldFolder: String, to newFolder: String) {
        for i in entries.indices {
            var entry = entries[i]
            if let audioPath = entry.audioPath, audioPath.hasPrefix(oldFolder + "/") {
                let newAudioPath = newFolder + audioPath.dropFirst(oldFolder.count)
                entry = AudioEntry(
                    id: entry.id,
                    text: entry.text,
                    audioPath: String(newAudioPath),
                    imagePath: entry.imagePath.map { path in
                        path.hasPrefix(oldFolder + "/") ? newFolder + path.dropFirst(oldFolder.count) : path
                    },
                    createdAt: entry.createdAt
                )
            } else if let imagePath = entry.imagePath, imagePath.hasPrefix(oldFolder + "/") {
                entry = AudioEntry(
                    id: entry.id,
                    text: entry.text,
                    audioPath: entry.audioPath,
                    imagePath: newFolder + imagePath.dropFirst(oldFolder.count),
                    createdAt: entry.createdAt
                )
            }
            entries[i] = entry
        }
        // Rewrite audioPath if present
        if let ap = audioPath, ap.hasPrefix(oldFolder + "/") {
            audioPath = newFolder + ap.dropFirst(oldFolder.count)
        }
        // Rewrite coverImagePath if present
        if let cip = coverImagePath, cip.hasPrefix(oldFolder + "/") {
            coverImagePath = newFolder + cip.dropFirst(oldFolder.count)
        }
    }

    // MARK: - Cover Image Mutation

    /// Establece la imagen de portada del proyecto
    /// - Parameter path: Path a la imagen de portada
    func setCoverImage(path: String) {
        self.coverImagePath = path
        touch()
    }

    /// Elimina la imagen de portada del proyecto
    func removeCoverImage() {
        self.coverImagePath = nil
        touch()
    }

    // MARK: - Folder Assignment

    /// Asigna el proyecto a una carpeta (o lo quita si se pasa nil)
    func assignToFolder(_ folderId: Identifier<Folder>?) {
        self.folderId = folderId
        touch()
    }

    // MARK: - TextContent Mutation

    /// Actualiza el texto del proyecto
    /// - Invalida el audio existente
    /// - Cambia estado a draft
    /// - Parameter newText: El nuevo texto
    func updateText(_ newText: TextContent) throws {
        self.text = newText
        invalidateAudio()
        touch()
        addEvent(ProjectTextUpdatedEvent(projectId: id, newText: newText))
    }

    // MARK: - Name Mutation

    /// Renombra el proyecto
    /// - NO invalida el audio
    /// - Parameter newName: El nuevo nombre
    func rename(_ newName: ProjectName) throws {
        self.name = newName
        touch()
        addEvent(ProjectRenamedEvent(projectId: id, newName: newName))
    }

    // MARK: - Voice Mutation

    /// Actualiza la configuración de voz
    /// - Invalida el audio existente
    /// - Cambia estado a draft
    /// - Parameter newConfiguration: Nueva configuración
    func updateVoiceConfiguration(_ newConfiguration: VoiceConfiguration) throws {
        self.voiceConfiguration = newConfiguration
        invalidateAudio()
        touch()
    }

    /// Actualiza la voz utilizada
    /// - Invalida el audio existente
    /// - Cambia estado a draft
    /// - Parameter newVoice: Nueva voz
    func updateVoice(_ newVoice: Voice) {
        self.voice = newVoice
        invalidateAudio()
        touch()
    }

    // MARK: - Audio Status Mutation

    /// Marca el proyecto como "generando audio"
    func markGenerating() {
        self.status = .generating
        touch()
    }

    /// Marca el audio como generado
    /// - Parameters:
    ///   - path: Path al archivo de audio generado
    func markAudioGenerated(path: String) {
        self.audioPath = path
        self.status = .ready
        touch()
        addEvent(AudioGeneratedEvent(projectId: id, audioPath: path))
    }

    /// Marca el proyecto con error
    func markError() {
        self.status = .error
        touch()
    }

    // MARK: - Entry Management

    /// Agrega una entrada al proyecto
    /// - Parameter entry: La entrada a agregar
    func addEntry(_ entry: AudioEntry) throws {
        entries.append(entry)
        touch()
        addEvent(EntryAddedEvent(projectId: id, entryId: entry.id))
    }

    /// Elimina una entrada del proyecto
    /// - Parameter id: ID de la entrada a eliminar
    /// - Throws: DomainError.entryNotFound si no existe
    func removeEntry(id: EntryId) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw DomainError.entryNotFound
        }
        entries.remove(at: index)
        touch()
        addEvent(EntryRemovedEvent(projectId: self.id, entryId: id))
    }

    /// Actualiza una entrada existente
    /// - Parameter entry: La entrada actualizada
    /// - Throws: DomainError.entryNotFound si no existe
    func updateEntry(_ entry: AudioEntry) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw DomainError.entryNotFound
        }
        entries[index] = entry
        touch()
        addEvent(EntryUpdatedEvent(projectId: id, entryId: entry.id))
    }

    // MARK: - Domain Events

    /// Limpia los eventos de dominio acumulados
    /// (útil después de persistir los eventos)
    func clearEvents() {
        domainEvents.removeAll()
    }

    // MARK: - Private Helpers

    /// Invalida el audio generado
    private func invalidateAudio() {
        self.audioPath = nil
        self.status = .draft
    }

    /// Actualiza el timestamp de modificación
    private func touch() {
        self.updatedAt = Date()
    }

    /// Agrega un evento de dominio
    private func addEvent(_ event: DomainEvent) {
        domainEvents.append(event)
    }
}
