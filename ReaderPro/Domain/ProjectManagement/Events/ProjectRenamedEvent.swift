import Foundation

/// Evento emitido cuando se renombra un proyecto
struct ProjectRenamedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let newName: ProjectName
    let occurredAt: Date

    init(projectId: Identifier<Project>, newName: ProjectName) {
        self.projectId = projectId
        self.newName = newName
        self.occurredAt = Date()
    }
}
