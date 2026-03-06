import Foundation

/// Evento emitido cuando se crea un nuevo proyecto
struct ProjectCreatedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let name: ProjectName
    let occurredAt: Date

    init(projectId: Identifier<Project>, name: ProjectName) {
        self.projectId = projectId
        self.name = name
        self.occurredAt = Date()
    }
}
