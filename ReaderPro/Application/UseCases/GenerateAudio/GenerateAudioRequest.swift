import Foundation

/// Request DTO para generar audio de un proyecto existente
struct GenerateAudioRequest {
    let projectId: Identifier<Project>

    init(projectId: Identifier<Project>) {
        self.projectId = projectId
    }
}
