import Foundation

/// Response DTO después de crear un proyecto
/// Contiene los datos relevantes para la UI
struct CreateProjectResponse {
    let projectId: Identifier<Project>
    let projectName: String
    let folderName: String?
    let status: ProjectStatus
    let createdAt: Date

    init(
        projectId: Identifier<Project>,
        projectName: String,
        folderName: String? = nil,
        status: ProjectStatus,
        createdAt: Date
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.folderName = folderName
        self.status = status
        self.createdAt = createdAt
    }
}
