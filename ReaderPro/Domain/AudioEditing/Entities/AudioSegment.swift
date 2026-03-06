import Foundation

/// Entity que representa un segmento de audio editado
/// Contiene texto, rango temporal y path opcional al audio del segmento
/// - Tiene identidad única
/// - Mutable struct con métodos controlados
/// - Usado para edición de audio (trim, split, etc.)
struct AudioSegment: Equatable, Hashable, Identifiable {
    typealias SegmentId = Identifier<AudioSegment>

    let id: SegmentId
    let text: TextContent
    let timeRange: TimeRange
    private(set) var audioPath: String?

    /// Crea un nuevo segmento (generación de ID automática)
    /// - Parameters:
    ///   - text: El texto del segmento
    ///   - timeRange: El rango temporal del segmento en el audio
    ///   - audioPath: Path opcional al archivo de audio del segmento
    init(text: TextContent, timeRange: TimeRange, audioPath: String? = nil) {
        self.id = SegmentId()
        self.text = text
        self.timeRange = timeRange
        self.audioPath = audioPath
    }

    /// Reconstitución desde persistencia
    /// - Parameters:
    ///   - id: ID existente
    ///   - text: El texto del segmento
    ///   - timeRange: El rango temporal del segmento
    ///   - audioPath: Path opcional al archivo de audio
    init(id: SegmentId, text: TextContent, timeRange: TimeRange, audioPath: String?) {
        self.id = id
        self.text = text
        self.timeRange = timeRange
        self.audioPath = audioPath
    }

    // MARK: - Computed Properties

    /// Duración del segmento en segundos
    var duration: TimeInterval {
        timeRange.duration
    }

    /// Indica si el segmento tiene audio generado
    var hasAudio: Bool {
        audioPath != nil
    }

    // MARK: - Mutating Methods

    /// Establece el path del audio del segmento
    mutating func setAudioPath(_ path: String) {
        self.audioPath = path
    }

    // MARK: - Domain Logic

    /// Verifica si un tiempo específico está contenido en este segmento
    /// - Parameter time: El tiempo a verificar
    /// - Returns: true si el tiempo está en el rango del segmento
    func containsTime(_ time: TimeInterval) -> Bool {
        timeRange.contains(time)
    }

    /// Verifica si este segmento se solapa con otro segmento
    /// - Parameter other: El otro segmento a verificar
    /// - Returns: true si los segmentos se solapan
    func overlaps(with other: AudioSegment) -> Bool {
        timeRange.overlaps(with: other.timeRange)
    }

    // MARK: - Equatable (por ID)

    static func == (lhs: AudioSegment, rhs: AudioSegment) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable (por ID)

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
