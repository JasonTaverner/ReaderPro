import Foundation

/// Port para servicios de captura de pantalla
/// Define la interfaz que deben implementar los adaptadores de captura
/// (ScreenCaptureService, etc.)
protocol ScreenCapturePort {
    /// Captura interactiva: el usuario selecciona una región de pantalla
    /// - Returns: Imagen capturada con datos y path temporal
    /// - Throws: Error si la captura falla o el usuario cancela
    func captureInteractive() async throws -> CapturedImage
}
