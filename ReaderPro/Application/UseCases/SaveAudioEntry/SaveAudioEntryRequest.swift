import Foundation

/// Request DTO para guardar una entrada de audio + texto
/// Usado en el flujo de captura de pantalla + OCR + TTS
struct SaveAudioEntryRequest {
    let projectId: Identifier<Project>
    let text: String
    let audioData: Data?  // nil si no se genera audio (solo texto + imagen)
    let audioDuration: TimeInterval?  // Duración del audio (opcional, se estima si no se provee)
    let imagePath: String?  // Path opcional a la captura de pantalla

    init(
        projectId: Identifier<Project>,
        text: String,
        audioData: Data? = nil,
        audioDuration: TimeInterval? = nil,
        imagePath: String? = nil
    ) {
        self.projectId = projectId
        self.text = text
        self.audioData = audioData
        self.audioDuration = audioDuration
        self.imagePath = imagePath
    }
}
