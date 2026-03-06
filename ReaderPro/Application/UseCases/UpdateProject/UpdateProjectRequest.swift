import Foundation

/// Request DTO para actualizar un proyecto existente
/// Todos los campos son opcionales (excepto projectId)
/// Solo los campos provistos serán actualizados
struct UpdateProjectRequest {
    let projectId: Identifier<Project>

    // Optional updates
    let name: String?
    let text: String?

    // Voice configuration updates
    let voiceId: String?
    let voiceName: String?
    let voiceLanguage: String?
    let voiceProvider: Voice.TTSProvider?
    let speed: Double?

    // Entry text updates (entryId -> newText)
    let entryTextUpdates: [String: String]?

    // Entry IDs to delete
    let entriesToDelete: [String]?

    // Entry IDs to toggle read status
    let entryReadToggles: [String]?

    init(
        projectId: Identifier<Project>,
        name: String? = nil,
        text: String? = nil,
        voiceId: String? = nil,
        voiceName: String? = nil,
        voiceLanguage: String? = nil,
        voiceProvider: Voice.TTSProvider? = nil,
        speed: Double? = nil,
        entryTextUpdates: [String: String]? = nil,
        entriesToDelete: [String]? = nil,
        entryReadToggles: [String]? = nil
    ) {
        self.projectId = projectId
        self.name = name
        self.text = text
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.voiceLanguage = voiceLanguage
        self.voiceProvider = voiceProvider
        self.speed = speed
        self.entryTextUpdates = entryTextUpdates
        self.entriesToDelete = entriesToDelete
        self.entryReadToggles = entryReadToggles
    }
}
