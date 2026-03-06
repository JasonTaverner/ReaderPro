import Foundation

/// Response DTO con los datos de un proyecto
/// Contiene todos los campos en formato serializable para la UI
struct GetProjectResponse {
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

    // Metadata
    let folderName: String?
    let entries: [AudioEntry]
    let entriesCount: Int
    let createdAt: Date
    let updatedAt: Date

    // Computed properties
    var hasAudio: Bool {
        audioPath != nil
    }

    /// Convenience init from a Project domain entity
    init(project: Project) {
        self.projectId = project.id
        self.name = project.name.value
        self.text = project.text?.value ?? ""
        self.status = project.status
        self.audioPath = project.audioPath
        self.voiceId = project.voiceConfiguration.voiceId
        self.voiceName = project.voice.name
        self.voiceLanguage = project.voice.language
        self.voiceProvider = project.voice.provider
        self.speed = project.voiceConfiguration.speed.value
        self.folderName = project.folderName
        self.entries = project.entries
        self.entriesCount = project.entries.count
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
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
        entries: [AudioEntry],
        entriesCount: Int,
        createdAt: Date,
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
        self.entries = entries
        self.entriesCount = entriesCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
