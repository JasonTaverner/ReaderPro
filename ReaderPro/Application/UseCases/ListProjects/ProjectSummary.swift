import Foundation

/// DTO resumido de un proyecto para listados
/// Más ligero que GetProjectResponse
struct ProjectSummary {
    let projectId: Identifier<Project>
    let name: String
    let textPreview: String  // Truncated text (first 100 chars)
    let status: ProjectStatus
    let hasAudio: Bool
    let voiceName: String
    let voiceProvider: Voice.TTSProvider
    let thumbnailPath: String?
    let folderName: String?
    let folderId: Identifier<Folder>?
    let createdAt: Date
    let updatedAt: Date

    init(
        projectId: Identifier<Project>,
        name: String,
        textPreview: String,
        status: ProjectStatus,
        hasAudio: Bool,
        voiceName: String,
        voiceProvider: Voice.TTSProvider,
        thumbnailPath: String? = nil,
        folderName: String? = nil,
        folderId: Identifier<Folder>? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projectId = projectId
        self.name = name
        self.textPreview = textPreview
        self.status = status
        self.hasAudio = hasAudio
        self.voiceName = voiceName
        self.voiceProvider = voiceProvider
        self.thumbnailPath = thumbnailPath
        self.folderName = folderName
        self.folderId = folderId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
