import Foundation

/// Evento emitido cuando se agrega una entrada a un proyecto
struct EntryAddedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let entryId: EntryId
    let occurredAt: Date

    init(projectId: Identifier<Project>, entryId: EntryId) {
        self.projectId = projectId
        self.entryId = entryId
        self.occurredAt = Date()
    }
}
