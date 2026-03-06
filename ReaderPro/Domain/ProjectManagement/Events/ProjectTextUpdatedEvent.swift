import Foundation

/// Evento emitido cuando se actualiza el texto de un proyecto
struct ProjectTextUpdatedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let newText: TextContent
    let occurredAt: Date

    init(projectId: Identifier<Project>, newText: TextContent) {
        self.projectId = projectId
        self.newText = newText
        self.occurredAt = Date()
    }
}
