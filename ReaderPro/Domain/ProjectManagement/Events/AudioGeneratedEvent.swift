import Foundation

/// Evento emitido cuando se genera el audio de un proyecto
struct AudioGeneratedEvent: DomainEvent {
    let projectId: Identifier<Project>
    let audioPath: String
    let occurredAt: Date

    init(projectId: Identifier<Project>, audioPath: String) {
        self.projectId = projectId
        self.audioPath = audioPath
        self.occurredAt = Date()
    }
}
