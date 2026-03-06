import Foundation

/// Response del caso de uso de merge de proyecto
struct MergeProjectResponse {
    /// ID del proyecto procesado
    let projectId: Identifier<Project>

    /// Nombre del proyecto
    let projectName: String

    /// Número de entries procesadas
    let entriesProcessed: Int

    /// Path al audio mergeado (nil si no se solicitó merge de audio)
    let mergedAudioPath: String?

    /// Path al PDF con imágenes (nil si no se solicitó merge de imágenes)
    let mergedPDFPath: String?

    /// Path al texto completo (nil si no se solicitó merge de texto)
    let mergedTextPath: String?

    /// Duración total del audio mergeado en segundos (nil si no hay audio)
    let totalAudioDuration: TimeInterval?

    /// Número de páginas del PDF generado (nil si no hay PDF)
    let pdfPageCount: Int?

    /// Directorio donde se guardaron los archivos
    let exportsDirectory: String
}
