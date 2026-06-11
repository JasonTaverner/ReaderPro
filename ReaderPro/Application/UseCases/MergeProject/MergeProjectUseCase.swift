import Foundation

/// Use Case para fusionar las entradas de un proyecto en archivos consolidados
/// - Audio: audio_completo.wav (con silencio entre cada archivo)
/// - Imágenes: documento.pdf (una imagen por página)
/// - Texto: documento_completo.txt (concatenación de todos los textos)
final class MergeProjectUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort
    private let audioEditor: AudioEditorPort
    /// Directorio base de la biblioteca, para resolver paths absolutos del audiolibro
    private let baseDirectory: String
    private let pdfGenerator: PDFGeneratorPort
    private let fileStorage: FileStoragePort

    // MARK: - Initialization

    init(
        projectRepository: ProjectRepositoryPort,
        audioEditor: AudioEditorPort,
        baseDirectory: String = "",
        pdfGenerator: PDFGeneratorPort,
        fileStorage: FileStoragePort
    ) {
        self.projectRepository = projectRepository
        self.audioEditor = audioEditor
        self.baseDirectory = baseDirectory
        self.pdfGenerator = pdfGenerator
        self.fileStorage = fileStorage
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de fusión de proyecto
    /// - Parameter request: Request con projectId y tipo de merge
    /// - Returns: Response con los paths de los archivos fusionados
    /// - Throws: ApplicationError o errores de dominio/infraestructura
    func execute(_ request: MergeProjectRequest) async throws -> MergeProjectResponse {
        // 1. Buscar el proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 2. Validar que tiene entradas
        guard !project.entries.isEmpty else {
            throw ApplicationError.noEntriesToMerge
        }

        // 3. Crear directorio exports si no existe
        let exportsDirectory = buildExportsDirectory(for: project)
        try await fileStorage.createDirectory(at: exportsDirectory)

        // 4. Ejecutar merge según tipo
        var mergedAudioPath: String?
        var mergedPDFPath: String?
        var mergedTextPath: String?
        var totalAudioDuration: TimeInterval?
        var pdfPageCount: Int?

        switch request.mergeType {
        case .audio:
            (mergedAudioPath, totalAudioDuration) = try await mergeAudio(
                entries: project.entries,
                exportsDirectory: exportsDirectory,
                silenceDuration: request.silenceBetweenAudios
            )

        case .audiobook:
            (mergedAudioPath, totalAudioDuration) = try await mergeAudiobook(
                project: project,
                exportsDirectory: exportsDirectory,
                silenceDuration: request.silenceBetweenAudios
            )

        case .images:
            (mergedPDFPath, pdfPageCount) = try await mergeImages(
                entries: project.entries,
                exportsDirectory: exportsDirectory
            )

        case .text:
            mergedTextPath = try await mergeText(
                entries: project.entries,
                exportsDirectory: exportsDirectory
            )

        case .all:
            (mergedAudioPath, totalAudioDuration) = try await mergeAudio(
                entries: project.entries,
                exportsDirectory: exportsDirectory,
                silenceDuration: request.silenceBetweenAudios
            )
            (mergedPDFPath, pdfPageCount) = try await mergeImages(
                entries: project.entries,
                exportsDirectory: exportsDirectory
            )
            mergedTextPath = try await mergeText(
                entries: project.entries,
                exportsDirectory: exportsDirectory
            )
        }

        // 5. Retornar response
        return MergeProjectResponse(
            projectId: project.id,
            projectName: project.name.value,
            entriesProcessed: project.entries.count,
            mergedAudioPath: mergedAudioPath,
            mergedPDFPath: mergedPDFPath,
            mergedTextPath: mergedTextPath,
            totalAudioDuration: totalAudioDuration,
            pdfPageCount: pdfPageCount,
            exportsDirectory: exportsDirectory
        )
    }

    // MARK: - Private Methods

    /// Construye el path del directorio exports para el proyecto
    private func buildExportsDirectory(for project: Project) -> String {
        // El directorio exports está dentro del directorio del proyecto
        let projectDirectory = project.folderName ?? project.id.value.uuidString
        return "\(projectDirectory)/exports"
    }

    /// Fusiona todos los audios de las entradas con silencio entre ellos
    /// - Returns: Tuple con path al audio fusionado y duración total, o nil si no hay audios
    private func mergeAudio(
        entries: [AudioEntry],
        exportsDirectory: String,
        silenceDuration: TimeInterval
    ) async throws -> (String?, TimeInterval?) {
        // Filtrar entradas con audio
        let audioPaths = entries.compactMap { $0.audioPath }

        guard !audioPaths.isEmpty else {
            return (nil, nil)
        }

        // Generar path de salida
        let outputPath = "\(exportsDirectory)/audio_completo.wav"

        // Concatenar audios con silencio
        let mergedPath = try await audioEditor.concatenate(
            audioPaths: audioPaths,
            silenceDuration: silenceDuration,
            outputPath: outputPath
        )

        // Obtener duración total
        let duration = try await audioEditor.getDuration(audioPath: mergedPath)

        return (mergedPath, duration)
    }

    /// Exporta el proyecto como audiolibro .m4b con capítulos navegables
    private func mergeAudiobook(
        project: Project,
        exportsDirectory: String,
        silenceDuration: TimeInterval
    ) async throws -> (String?, TimeInterval?) {
        let base = URL(fileURLWithPath: baseDirectory, isDirectory: true)

        // Capítulo por entrada con audio; el título sale del texto de la entrada
        var chapters: [AudiobookChapter] = []
        for (index, entry) in project.entries.enumerated() {
            guard let audioPath = entry.audioPath else { continue }
            let words = entry.text.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ").prefix(7).joined(separator: " ")
            let title = words.isEmpty ? "Capítulo \(index + 1)" : "\(index + 1). \(words)"
            chapters.append(AudiobookChapter(
                audioURL: base.appendingPathComponent(audioPath),
                title: title
            ))
        }

        guard !chapters.isEmpty else { return (nil, nil) }

        let safeName = project.name.value.replacingOccurrences(of: "/", with: "-")
        let outputRelative = "\(exportsDirectory)/\(safeName).m4b"
        let outputAbsolute = base.appendingPathComponent(outputRelative).path

        let duration = try await audioEditor.exportAudiobook(
            chapters: chapters,
            outputPath: outputAbsolute,
            silenceDuration: silenceDuration,
            bookTitle: project.name.value
        )

        return (outputRelative, duration)
    }

    /// Fusiona todas las imágenes de las entradas en un PDF
    /// - Returns: Tuple con path al PDF y número de páginas, o nil si no hay imágenes
    private func mergeImages(
        entries: [AudioEntry],
        exportsDirectory: String
    ) async throws -> (String?, Int?) {
        // Filtrar entradas con imagen
        let imagePaths = entries.compactMap { $0.imagePath }

        guard !imagePaths.isEmpty else {
            return (nil, nil)
        }

        // Generar path de salida
        let outputPath = "\(exportsDirectory)/documento.pdf"

        // Generar PDF
        let pdfPath = try await pdfGenerator.generatePDF(
            from: imagePaths,
            outputPath: outputPath
        )

        return (pdfPath, imagePaths.count)
    }

    /// Fusiona todos los textos de las entradas en un archivo
    /// - Returns: Path al archivo de texto fusionado
    private func mergeText(
        entries: [AudioEntry],
        exportsDirectory: String
    ) async throws -> String {
        // Concatenar todos los textos con separadores
        var mergedText = ""
        for (index, entry) in entries.enumerated() {
            if index > 0 {
                mergedText += "\n\n---\n\n"  // Separador entre entradas
            }
            mergedText += entry.text.value
        }

        // Generar path de salida
        let outputPath = "\(exportsDirectory)/documento_completo.txt"

        // Guardar texto
        try await fileStorage.saveText(mergedText, to: outputPath)

        return outputPath
    }
}
