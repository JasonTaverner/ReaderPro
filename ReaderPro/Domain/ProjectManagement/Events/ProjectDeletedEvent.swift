import Foundation

/// Evento emitido cuando se elimina un proyecto
struct ProjectDeletedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let projectName: String
    let occurredAt: Date

    init(projectId: Identifier<Project>, projectName: String) {
        self.projectId = projectId
        self.projectName = projectName
        self.occurredAt = Date()
    }
}
