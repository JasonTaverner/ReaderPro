import Foundation

/// Evento emitido cuando se actualiza una entrada en un proyecto
struct EntryUpdatedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let entryId: EntryId
    let occurredAt: Date

    init(projectId: Identifier<Project>, entryId: EntryId) {
        self.projectId = projectId
        self.entryId = entryId
        self.occurredAt = Date()
    }
}
