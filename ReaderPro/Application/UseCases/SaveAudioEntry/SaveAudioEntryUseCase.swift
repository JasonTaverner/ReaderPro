import Foundation

/// Use Case para guardar una entrada de audio + texto en un proyecto
/// Usado en el flujo de captura de pantalla + OCR + TTS
/// Crea archivos numerados secuencialmente (001.txt, 001.wav, 001.png)
final class SaveAudioEntryUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort
    private let audioStorage: AudioStoragePort
    private let fileStorage: FileStoragePort

    // MARK: - Initialization

    init(
        projectRepository: ProjectRepositoryPort,
        audioStorage: AudioStoragePort,
        fileStorage: FileStoragePort
    ) {
        self.projectRepository = projectRepository
        self.audioStorage = audioStorage
        self.fileStorage = fileStorage
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de guardar entrada de audio
    /// - Parameter request: Request con texto, audio e imagen
    /// - Returns: Response con los paths de los archivos guardados
    /// - Throws: ApplicationError o errores de dominio/infraestructura
    func execute(_ request: SaveAudioEntryRequest) async throws -> SaveAudioEntryResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Calcular el número del siguiente entry (basado en cantidad actual)
        let entryNumber = project.entries.count + 1

        // 3. Validar y crear Value Objects del dominio
        let text = try TextContent(request.text)

        // 4. Determine the project's folder name on disk
        guard let projectFolder = project.folderName else {
            throw ApplicationError.projectNotFound  // Project must have been saved first
        }
        let textPath = fileStorage.generateNumberedPath(
            baseDirectory: projectFolder,
            number: entryNumber,
            extension: "txt"
        )

        // 5. Guardar el texto en archivo
        try await fileStorage.saveText(request.text, to: textPath)

        // 6. Guardar audio si se proporcionó (numerado secuencialmente: 001.wav, 002.wav)
        var savedAudioPath: String? = nil
        if let audioBytes = request.audioData, !audioBytes.isEmpty {
            let duration = request.audioDuration ?? estimateDuration(from: audioBytes)
            let audioData = try AudioData(data: audioBytes, duration: duration)
            savedAudioPath = try await audioStorage.save(
                audioData: audioData,
                folderName: projectFolder,
                entryNumber: entryNumber
            )
        }

        // 7. Guardar imagen si se proporcionó (copiar a almacenamiento permanente)
        // Se guarda con formato numerado como el texto: 001.png, 002.png, etc.
        var savedImagePath: String? = nil
        if let sourceImagePath = request.imagePath {
            let sourceURL = URL(fileURLWithPath: sourceImagePath)
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                let imageData = try Data(contentsOf: sourceURL)
                let imagePath = fileStorage.generateNumberedPath(
                    baseDirectory: projectFolder,
                    number: entryNumber,
                    extension: "png"
                )
                try await fileStorage.save(data: imageData, to: imagePath)
                savedImagePath = imagePath
            }
        }

        // 8. Crear AudioEntry con los paths
        let entry = AudioEntry(
            text: text,
            audioPath: savedAudioPath,
            imagePath: savedImagePath
        )

        // 9. Añadir el entry al proyecto
        try project.addEntry(entry)

        // 10. Persistir proyecto actualizado
        try await projectRepository.save(project)

        // 12. Retornar response
        return SaveAudioEntryResponse(
            entryId: formatEntryId(entryNumber),
            entryNumber: entryNumber,
            textPath: textPath,
            audioPath: savedAudioPath ?? textPath,  // Fallback to textPath if no audio
            imagePath: savedImagePath
        )
    }

    // MARK: - Private Helpers

    /// Estima la duración del audio basado en el tamaño del archivo
    /// Asume WAV format: ~176KB por segundo (44.1kHz, 16-bit, stereo)
    private func estimateDuration(from audioData: Data) -> TimeInterval {
        let bytesPerSecond: Double = 176_400  // 44.1kHz * 16-bit * 2 channels
        let duration = Double(audioData.count) / bytesPerSecond
        return max(duration, 1.0)  // Mínimo 1 segundo
    }

    /// Formatea el número de entry como ID (001, 002, 003...)
    private func formatEntryId(_ number: Int) -> String {
        String(format: "%03d", number)
    }
}
