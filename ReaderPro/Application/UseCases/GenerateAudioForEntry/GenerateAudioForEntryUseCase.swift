import Foundation

/// Caso de uso para generar audio de una entrada existente sin audio
/// Permite agregar audio a entries que fueron creados solo con texto + imagen
final class GenerateAudioForEntryUseCase {

    // MARK: - Dependencies

    private let projectRepository: ProjectRepositoryPort
    private let ttsPort: TTSPort
    private let audioStorage: AudioStoragePort

    // MARK: - Initialization

    init(
        projectRepository: ProjectRepositoryPort,
        ttsPort: TTSPort,
        audioStorage: AudioStoragePort
    ) {
        self.projectRepository = projectRepository
        self.ttsPort = ttsPort
        self.audioStorage = audioStorage
    }

    // MARK: - Execution

    /// Genera audio para una entrada existente
    /// - Parameter request: Request con projectId, entryId y configuración de voz
    /// - Returns: Response con el path del audio generado
    /// - Throws: ApplicationError o errores de dominio/infraestructura
    func execute(_ request: GenerateAudioForEntryRequest) async throws -> GenerateAudioForEntryResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Buscar la entrada en el proyecto
        guard let entryIndex = project.entries.firstIndex(where: { $0.id == request.entryId }) else {
            throw ApplicationError.entryNotFound
        }

        var entry = project.entries[entryIndex]

        // 3. Si ya tiene audio, se sobreescribirá (regeneración)

        // 4. Generar audio via TTS
        let audioData = try await ttsPort.synthesize(
            text: entry.text,
            voiceConfiguration: request.voiceConfiguration,
            voice: request.voice
        )

        // 5. Guardar audio en almacenamiento
        guard let folderName = project.folderName else {
            throw ApplicationError.projectNotFound
        }
        // Use entry's position in the project for sequential numbering
        let audioEntryNumber = (entryIndex + 1)
        let audioPath = try await audioStorage.save(
            audioData: audioData,
            folderName: folderName,
            entryNumber: audioEntryNumber
        )

        // 6. Actualizar la entrada con el path del audio
        entry.setAudioPath(audioPath)
        try project.updateEntry(entry)

        // 7. Persistir proyecto actualizado
        try await projectRepository.save(project)

        print("[GenerateAudioForEntry] Audio generated for entry \(entry.id.value) at: \(audioPath)")

        // 8. Retornar response
        return GenerateAudioForEntryResponse(
            entryId: entry.id,
            audioPath: audioPath,
            duration: audioData.duration
        )
    }
}
