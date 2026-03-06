import Foundation

/// Request DTO para eliminar un proyecto
struct DeleteProjectRequest {
    let projectId: Identifier<Project>

    init(projectId: Identifier<Project>) {
        self.projectId = projectId
    }
}
