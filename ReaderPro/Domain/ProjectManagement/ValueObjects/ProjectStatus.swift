import Foundation

/// Value Object enum que representa el estado de un proyecto
/// - draft: Sin audio generado
/// - generating: Generando audio (proceso en curso)
/// - ready: Audio listo para reproducir
/// - error: Error en la generación
enum ProjectStatus: String, Equatable, CaseIterable {
    case draft      // Sin audio generado
    case generating // Generando audio
    case ready      // Audio listo
    case error      // Error en generación

    /// Nombre legible para mostrar en UI
    var displayName: String {
        switch self {
        case .draft:
            return "Borrador"
        case .generating:
            return "Generando..."
        case .ready:
            return "Listo"
        case .error:
            return "Error"
        }
    }

    /// Indica si el proyecto está siendo procesado actualmente
    var isProcessing: Bool {
        self == .generating
    }

    /// Indica si el proyecto tiene audio disponible
    var hasAudio: Bool {
        self == .ready
    }

    /// Indica si se puede regenerar el audio
    /// - No se puede regenerar mientras está generando
    var canRegenerate: Bool {
        self != .generating
    }
}
