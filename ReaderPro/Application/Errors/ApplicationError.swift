import Foundation

/// Errores de la capa de aplicación (Use Cases)
enum ApplicationError: Error, Equatable {
    case projectNotFound
    case projectHasNoText
    case projectAlreadyGenerating
    case audioGenerationFailed(String)
    case audioStorageFailed(String)
    case entryNotFound
    case entryAlreadyHasAudio
    case noEntriesToMerge
    case mergeFailed(String)
    case textProcessingFailed(String)

    var localizedDescription: String {
        switch self {
        case .projectNotFound:
            return "Proyecto no encontrado"
        case .projectHasNoText:
            return "El proyecto no tiene texto para generar audio"
        case .projectAlreadyGenerating:
            return "El proyecto ya está generando audio"
        case .audioGenerationFailed(let reason):
            return "Error al generar audio: \(reason)"
        case .audioStorageFailed(let reason):
            return "Error al guardar audio: \(reason)"
        case .entryNotFound:
            return "Entrada no encontrada"
        case .entryAlreadyHasAudio:
            return "La entrada ya tiene audio generado"
        case .noEntriesToMerge:
            return "El proyecto no tiene entradas para fusionar"
        case .mergeFailed(let reason):
            return "Error al fusionar: \(reason)"
        case .textProcessingFailed(let reason):
            return "Error al procesar texto: \(reason)"
        }
    }
}
