import Foundation

/// Errores específicos de la capa de infraestructura para OCR
enum OCRError: LocalizedError, Equatable {
    case invalidImageFormat
    case recognitionFailed(String)
    case noTextFound
    case visionNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Formato de imagen no soportado para OCR"
        case .recognitionFailed(let reason):
            return "Error en reconocimiento OCR: \(reason)"
        case .noTextFound:
            return "No se encontró texto en la imagen"
        case .visionNotAvailable:
            return "Vision framework no disponible"
        }
    }
}
