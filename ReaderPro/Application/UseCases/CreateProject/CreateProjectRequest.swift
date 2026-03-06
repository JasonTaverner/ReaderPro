import Foundation

/// Request DTO para crear un nuevo proyecto
/// Contiene todos los datos necesarios desde la capa de presentación
struct CreateProjectRequest {
    let text: String?
    let name: String?
    let voiceId: String?
    let voiceName: String?
    let voiceLanguage: String?
    let voiceProvider: Voice.TTSProvider?
    let speed: Double?
    let folderId: Identifier<Folder>?

    /// Inicializador completo con texto y voz
    init(
        text: String,
        name: String? = nil,
        voiceId: String,
        voiceName: String,
        voiceLanguage: String,
        voiceProvider: Voice.TTSProvider,
        speed: Double? = nil,
        folderId: Identifier<Folder>? = nil
    ) {
        self.text = text
        self.name = name
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.voiceLanguage = voiceLanguage
        self.voiceProvider = voiceProvider
        self.speed = speed
        self.folderId = folderId
    }

    /// Inicializador simplificado para crear proyecto vacío (solo nombre)
    init(name: String, folderId: Identifier<Folder>? = nil) {
        self.text = nil
        self.name = name
        self.voiceId = nil
        self.voiceName = nil
        self.voiceLanguage = nil
        self.voiceProvider = nil
        self.speed = nil
        self.folderId = folderId
    }
}
