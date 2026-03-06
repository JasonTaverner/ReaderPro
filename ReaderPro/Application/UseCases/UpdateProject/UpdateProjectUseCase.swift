import Foundation

/// Use Case para actualizar un proyecto existente
/// Permite actualizar nombre, texto y/o configuración de voz
/// Actualizar texto o voz invalida el audio existente
final class UpdateProjectUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort

    // MARK: - Initialization

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de actualización de proyecto
    /// - Parameter request: Request con los campos a actualizar
    /// - Returns: Response con el proyecto actualizado
    /// - Throws: ApplicationError.projectNotFound si no existe
    func execute(_ request: UpdateProjectRequest) async throws -> UpdateProjectResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Actualizar nombre si se provee
        if let newName = request.name {
            let projectName = try ProjectName(newName)
            try project.rename(projectName)
        }

        // 3. Actualizar texto si se provee Y ha cambiado (invalida audio solo si cambia)
        if let newText = request.text {
            let currentText = project.text?.value ?? ""
            if newText != currentText {
                print("[UpdateProjectUseCase] Text changed, invalidating audio")
                let text = try TextContent(newText)
                try project.updateText(text)
            } else {
                print("[UpdateProjectUseCase] Text unchanged, keeping audio path: \(project.audioPath ?? "nil")")
            }
        }

        // 4. Actualizar configuración de voz si se provee Y ha cambiado (invalida audio solo si cambia)
        let newSpeed = request.speed ?? project.voiceConfiguration.speed.value
        let newVoiceId = request.voiceId ?? project.voiceConfiguration.voiceId

        let speedChanged = request.speed != nil && request.speed != project.voiceConfiguration.speed.value
        let voiceIdChanged = request.voiceId != nil && request.voiceId != project.voiceConfiguration.voiceId

        if speedChanged || voiceIdChanged {
            print("[UpdateProjectUseCase] Voice config changed, invalidating audio")
            let speed = try VoiceConfiguration.Speed(newSpeed)
            let newConfig = VoiceConfiguration(
                voiceId: newVoiceId,
                speed: speed
            )
            try project.updateVoiceConfiguration(newConfig)
        }

        // 5. Actualizar voz si se provee Y ha cambiado (invalida audio solo si cambia)
        let voiceNameChanged = request.voiceName != nil && request.voiceName != project.voice.name
        let voiceLanguageChanged = request.voiceLanguage != nil && request.voiceLanguage != project.voice.language
        let voiceProviderChanged = request.voiceProvider != nil && request.voiceProvider != project.voice.provider

        if voiceIdChanged || voiceNameChanged || voiceLanguageChanged || voiceProviderChanged {
            print("[UpdateProjectUseCase] Voice changed, invalidating audio")
            let newVoice = Voice(
                id: request.voiceId ?? project.voice.id,
                name: request.voiceName ?? project.voice.name,
                language: request.voiceLanguage ?? project.voice.language,
                provider: request.voiceProvider ?? project.voice.provider,
                isDefault: false
            )
            project.updateVoice(newVoice)
        }

        // 6. Actualizar texto de entries si se provee
        if let entryTextUpdates = request.entryTextUpdates {
            for (entryIdString, newText) in entryTextUpdates {
                guard let entryUUID = UUID(uuidString: entryIdString) else { continue }
                let entryId = EntryId(entryUUID)
                guard let entryIndex = project.entries.firstIndex(where: { $0.id == entryId }) else { continue }

                var updatedEntry = project.entries[entryIndex]
                let currentText = updatedEntry.text.value
                if newText != currentText {
                    let textContent = try TextContent(newText)
                    updatedEntry.updateText(textContent)
                    try project.updateEntry(updatedEntry)
                    print("[UpdateProjectUseCase] Entry \(entryIdString) text updated")
                }
            }
        }

        // 7. Toggle read status de entries si se solicita
        if let entryReadToggles = request.entryReadToggles {
            for entryIdString in entryReadToggles {
                guard let entryUUID = UUID(uuidString: entryIdString) else { continue }
                let entryId = EntryId(entryUUID)
                guard let entryIndex = project.entries.firstIndex(where: { $0.id == entryId }) else { continue }

                var updatedEntry = project.entries[entryIndex]
                updatedEntry.toggleRead()
                try project.updateEntry(updatedEntry)
            }
        }

        // 8. Eliminar entries si se solicita
        if let entriesToDelete = request.entriesToDelete {
            for entryIdString in entriesToDelete {
                guard let entryUUID = UUID(uuidString: entryIdString) else { continue }
                let entryId = EntryId(entryUUID)
                do {
                    try project.removeEntry(id: entryId)
                    print("[UpdateProjectUseCase] Entry \(entryIdString) deleted")
                } catch {
                    print("[UpdateProjectUseCase] Failed to delete entry \(entryIdString): \(error)")
                }
            }
        }

        // 9. Persistir cambios
        print("[UpdateProjectUseCase] Saving project: \(project.name.value), audioPath: \(project.audioPath ?? "nil"), status: \(project.status.rawValue)")
        try await projectRepository.save(project)
        print("[UpdateProjectUseCase] Project saved successfully")

        // 10. Retornar response con el proyecto actualizado
        return UpdateProjectResponse(
            projectId: project.id,
            name: project.name.value,
            text: project.text?.value ?? "",
            status: project.status,
            audioPath: project.audioPath,
            voiceId: project.voiceConfiguration.voiceId,
            voiceName: project.voice.name,
            voiceLanguage: project.voice.language,
            voiceProvider: project.voice.provider,
            speed: project.voiceConfiguration.speed.value,
            folderName: project.folderName,
            updatedAt: project.updatedAt
        )
    }
}
