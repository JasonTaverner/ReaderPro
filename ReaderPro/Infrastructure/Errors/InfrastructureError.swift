import Foundation

/// Errores de la capa de infraestructura
enum InfrastructureError: LocalizedError {
    case fileNotFound(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)
    case directoryCreationFailed(String)
    case jsonEncodingFailed(Error)
    case jsonDecodingFailed(Error)
    case invalidProjectData(String)
    case ttsRequestFailed(String)
    case ttsServerUnavailable
    case ttsServerNotRunning(url: String)
    case ttsServerTimeout(url: String)
    case ttsModelNotFound(model: String)
    case ttsCloneAudioTooShort(duration: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Archivo no encontrado: \(path)"
        case .fileReadFailed(let path):
            return "Error al leer archivo: \(path)"
        case .fileWriteFailed(let path):
            return "Error al escribir archivo: \(path)"
        case .directoryCreationFailed(let path):
            return "Error al crear directorio: \(path)"
        case .jsonEncodingFailed(let error):
            return "Error al codificar JSON: \(error.localizedDescription)"
        case .jsonDecodingFailed(let error):
            return "Error al decodificar JSON: \(error.localizedDescription)"
        case .invalidProjectData(let reason):
            return "Datos de proyecto inválidos: \(reason)"
        case .ttsRequestFailed(let reason):
            return "Error en request de TTS: \(reason)"
        case .ttsServerUnavailable:
            return "Servidor TTS no disponible"
        case .ttsServerNotRunning(let url):
            return "El servidor TTS no está ejecutándose en \(url)"
        case .ttsServerTimeout(let url):
            return "Timeout conectando al servidor TTS en \(url). Verifica que el servidor esté activo."
        case .ttsModelNotFound(let model):
            return "Modelo TTS '\(model)' no encontrado"
        case .ttsCloneAudioTooShort(let duration):
            return "Audio de referencia demasiado corto (\(String(format: "%.1f", duration))s). Se requieren al menos 3 segundos."
        }
    }

    /// Mensaje de ayuda adicional para el usuario
    var recoverySuggestion: String? {
        switch self {
        case .ttsServerNotRunning:
            return """
            Sugerencias:
            - Cambia a "System (macOS)" en Settings para usar voces del sistema sin servidor
            - Verifica que la URL del servidor en Settings sea correcta
            - Asegúrate de que el servidor TTS esté iniciado antes de generar audio
            """
        case .ttsServerTimeout:
            return """
            Posibles causas:
            - El servidor puede estar cargando su modelo (espera unos segundos)
            - La URL del servidor en Settings puede ser incorrecta
            - Cambia a "System (macOS)" en Settings para usar voces del sistema sin servidor
            """
        case .ttsModelNotFound(let model):
            return """
            El modelo '\(model)' no está descargado en Ollama.
            Para descargarlo, ejecuta en Terminal:
                ollama pull \(model)
            """
        default:
            return nil
        }
    }
}
