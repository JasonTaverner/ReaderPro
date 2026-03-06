import Foundation

/// Use Case para generar audio de un proyecto existente
/// Coordina TTS, almacenamiento y actualización del proyecto
final class GenerateAudioUseCase {

    // MARK: - Properties

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

    /// Ejecuta el caso de uso de generación de audio
    /// - Parameter request: Request con el ID del proyecto
    /// - Returns: Response con el audio generado
    /// - Throws: ApplicationError o errores de dominio/infraestructura
    func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Validar que el proyecto tiene texto
        guard let projectText = project.text else {
            throw ApplicationError.projectHasNoText
        }

        // 3. Validar que puede regenerar (no está generando actualmente)
        guard project.canRegenerate else {
            throw ApplicationError.projectAlreadyGenerating
        }

        // 4. Marcar como "generating" y persistir
        project.markGenerating()
        try await projectRepository.save(project)

        // 5. Generar audio via TTS
        let audioData: AudioData
        do {
            audioData = try await ttsPort.synthesize(
                text: projectText,
                voiceConfiguration: project.voiceConfiguration,
                voice: project.voice
            )
        } catch {
            // Si falla TTS, marcar proyecto como error y propagar
            project.markError()
            try await projectRepository.save(project)
            throw error
        }

        // 6. Guardar audio en almacenamiento
        guard let folderName = project.folderName else {
            project.markError()
            try await projectRepository.save(project)
            throw ApplicationError.projectNotFound
        }
        let audioPath: String
        do {
            audioPath = try await audioStorage.save(
                audioData: audioData,
                folderName: folderName,
                entryNumber: nil
            )
        } catch {
            // Si falla el guardado, marcar proyecto como error y propagar
            project.markError()
            try await projectRepository.save(project)
            throw error
        }

        // 7. Marcar audio como generado (emite evento)
        print("[GenerateAudioUseCase] Audio saved to relative path: \(audioPath)")
        project.markAudioGenerated(path: audioPath)

        // 8. Persistir proyecto actualizado
        try await projectRepository.save(project)
        print("[GenerateAudioUseCase] Project saved with audioPath: \(project.audioPath ?? "nil")")

        // 9. Retornar response
        return GenerateAudioResponse(
            projectId: project.id,
            audioPath: audioPath,
            duration: audioData.duration,
            status: project.status
        )
    }
}
