import Foundation

/// Errores específicos de captura de pantalla
enum ScreenCaptureError: LocalizedError, Equatable {
    case processLaunchFailed(String)
    case captureFailed(String)
    case userCancelled
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let reason):
            return "No se pudo iniciar captura de pantalla: \(reason)"
        case .captureFailed(let reason):
            return "Error al capturar pantalla: \(reason)"
        case .userCancelled:
            return "Captura cancelada por el usuario"
        case .invalidImageData:
            return "Los datos de la imagen capturada son inválidos"
        }
    }
}
