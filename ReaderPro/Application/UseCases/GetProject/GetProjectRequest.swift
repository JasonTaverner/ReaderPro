import Foundation

/// Request DTO para obtener un proyecto existente
struct GetProjectRequest {
    let projectId: Identifier<Project>

    init(projectId: Identifier<Project>) {
        self.projectId = projectId
    }
}
