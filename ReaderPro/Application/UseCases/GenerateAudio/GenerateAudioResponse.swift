import Foundation

/// Response DTO después de generar audio
struct GenerateAudioResponse {
    let projectId: Identifier<Project>
    let audioPath: String
    let duration: TimeInterval
    let status: ProjectStatus

    init(
        projectId: Identifier<Project>,
        audioPath: String,
        duration: TimeInterval,
        status: ProjectStatus
    ) {
        self.projectId = projectId
        self.audioPath = audioPath
        self.duration = duration
        self.status = status
    }
}
