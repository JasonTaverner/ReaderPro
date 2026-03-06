import Foundation

/// Errores del dominio
/// El dominio define sus propios errores sin depender de frameworks externos
enum DomainError: Error, Equatable {
    case invalidText(String)
    case invalidProjectName(String)
    case invalidSpeed
    case invalidTimeRange(String)
    case invalidPageNumber
    case invalidImageDimensions
    case invalidConfidence
    case emptyRecognizedText
    case emptyImageData
    case emptyAudioData
    case invalidAudioDuration(String)
    case segmentsOverlap
    case projectNotFound
    case entryNotFound
    case invalidFolderName(String)

    var localizedDescription: String {
        switch self {
        case .invalidText(let reason):
            return "Texto inválido: \(reason)"
        case .invalidProjectName(let reason):
            return "Nombre de proyecto inválido: \(reason)"
        case .invalidSpeed:
            return "Velocidad inválida: debe estar entre 0.5 y 2.0"
        case .invalidTimeRange(let reason):
            return "Rango de tiempo inválido: \(reason)"
        case .invalidPageNumber:
            return "Número de página inválido"
        case .invalidImageDimensions:
            return "Dimensiones de imagen inválidas"
        case .invalidConfidence:
            return "Confianza inválida: debe estar entre 0.0 y 1.0"
        case .emptyRecognizedText:
            return "Texto reconocido vacío"
        case .emptyImageData:
            return "Datos de imagen vacíos"
        case .emptyAudioData:
            return "Datos de audio vacíos"
        case .invalidAudioDuration(let reason):
            return "Duración de audio inválida: \(reason)"
        case .segmentsOverlap:
            return "Los segmentos de audio se solapan"
        case .projectNotFound:
            return "Proyecto no encontrado"
        case .entryNotFound:
            return "Entrada no encontrada"
        case .invalidFolderName(let reason):
            return "Nombre de carpeta inválido: \(reason)"
        }
    }
}
