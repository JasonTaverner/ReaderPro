import Foundation

/// Response DTO con la lista de proyectos
struct ListProjectsResponse {
    let projects: [ProjectSummary]
    let totalCount: Int

    init(projects: [ProjectSummary]) {
        self.projects = projects
        self.totalCount = projects.count
    }
}
