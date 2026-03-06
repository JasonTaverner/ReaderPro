import Foundation

/// Response DTO después de eliminar un proyecto
struct DeleteProjectResponse {
    let projectId: Identifier<Project>
    let projectName: String
    let deleted: Bool
    let audioDeleted: Bool

    init(
        projectId: Identifier<Project>,
        projectName: String,
        deleted: Bool,
        audioDeleted: Bool
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.deleted = deleted
        self.audioDeleted = audioDeleted
    }
}
