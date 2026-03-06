import Foundation

/// Entity que representa una entrada individual en un proyecto
/// Contiene texto, rutas a audio e imagen, y metadata
/// - Tiene identidad única (EntryId)
/// - Mutable struct con métodos controlados
/// - Parte del Project aggregate
struct AudioEntry: Equatable, Hashable, Identifiable {
    let id: EntryId
    private(set) var text: TextContent
    private(set) var audioPath: String?
    private(set) var imagePath: String?
    private(set) var isRead: Bool
    let createdAt: Date

    /// Crea una nueva entrada (generación de ID automática)
    /// - Parameters:
    ///   - text: El texto de la entrada
    ///   - audioPath: Path opcional al archivo de audio
    ///   - imagePath: Path opcional a la imagen asociada
    init(text: TextContent, audioPath: String? = nil, imagePath: String? = nil, isRead: Bool = false) {
        self.id = EntryId()
        self.text = text
        self.audioPath = audioPath
        self.imagePath = imagePath
        self.isRead = isRead
        self.createdAt = Date()
    }

    /// Reconstitución desde persistencia
    /// - Parameters:
    ///   - id: ID existente
    ///   - text: El texto de la entrada
    ///   - audioPath: Path opcional al archivo de audio
    ///   - imagePath: Path opcional a la imagen asociada
    ///   - createdAt: Fecha de creación original
    init(id: EntryId, text: TextContent, audioPath: String?, imagePath: String?, isRead: Bool = false, createdAt: Date) {
        self.id = id
        self.text = text
        self.audioPath = audioPath
        self.imagePath = imagePath
        self.isRead = isRead
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Indica si la entrada tiene audio generado
    var hasAudio: Bool {
        audioPath != nil
    }

    /// Indica si la entrada tiene imagen asociada
    var hasImage: Bool {
        imagePath != nil
    }

    // MARK: - Mutating Methods

    /// Establece el path del audio generado
    mutating func setAudioPath(_ path: String) {
        self.audioPath = path
    }

    /// Establece el path de la imagen asociada
    mutating func setImagePath(_ path: String) {
        self.imagePath = path
    }

    /// Alterna el estado de lectura de la entrada
    mutating func toggleRead() {
        self.isRead = !self.isRead
    }

    /// Actualiza el texto de la entrada
    /// - Invalida el audio existente (texto cambió, audio ya no es válido)
    mutating func updateText(_ newText: TextContent) {
        self.text = newText
        self.audioPath = nil
    }

    // MARK: - Equatable (por ID)

    static func == (lhs: AudioEntry, rhs: AudioEntry) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable (por ID)

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
