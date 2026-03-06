import Foundation

/// Calidad de audio para exportación
enum AudioQuality: String, Equatable, CaseIterable {
    case low        // Baja calidad (más compresión, menor tamaño)
    case medium     // Calidad media
    case high       // Alta calidad
    case maximum    // Máxima calidad (sin comprimir o mínima compresión)

    /// Bitrate aproximado en kbps para formatos comprimidos
    var bitrate: Int {
        switch self {
        case .low: return 64
        case .medium: return 128
        case .high: return 192
        case .maximum: return 320
        }
    }

    /// Sample rate en Hz
    var sampleRate: Int {
        switch self {
        case .low: return 22050
        case .medium: return 44100
        case .high: return 44100
        case .maximum: return 48000
        }
    }

    /// Nombre legible de la calidad
    var displayName: String {
        switch self {
        case .low: return "Baja (64 kbps)"
        case .medium: return "Media (128 kbps)"
        case .high: return "Alta (192 kbps)"
        case .maximum: return "Máxima (320 kbps)"
        }
    }
}
