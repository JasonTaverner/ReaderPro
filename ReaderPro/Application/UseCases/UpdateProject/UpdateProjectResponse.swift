import Foundation

/// Response DTO después de actualizar un proyecto
/// Contiene el estado completo del proyecto actualizado
struct UpdateProjectResponse {
    let projectId: Identifier<Project>
    let name: String
    let text: String
    let status: ProjectStatus
    let audioPath: String?

    // Voice configuration
    let voiceId: String
    let voiceName: String
    let voiceLanguage: String
    let voiceProvider: Voice.TTSProvider
    let speed: Double

    // Folder
    let folderName: String?

    // Metadata
    let updatedAt: Date

    // Computed
    var hasAudio: Bool {
        audioPath != nil
    }

    init(
        projectId: Identifier<Project>,
        name: String,
        text: String,
        status: ProjectStatus,
        audioPath: String?,
        voiceId: String,
        voiceName: String,
        voiceLanguage: String,
        voiceProvider: Voice.TTSProvider,
        speed: Double,
        folderName: String? = nil,
        updatedAt: Date
    ) {
        self.projectId = projectId
        self.name = name
        self.text = text
        self.status = status
        self.audioPath = audioPath
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.voiceLanguage = voiceLanguage
        self.voiceProvider = voiceProvider
        self.speed = speed
        self.folderName = folderName
        self.updatedAt = updatedAt
    }
}
