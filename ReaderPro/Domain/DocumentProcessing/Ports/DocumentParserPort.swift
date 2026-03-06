import Foundation

/// Port para parseo de documentos (PDF, EPUB)
/// Define la interfaz que deben implementar los adaptadores de parseo
protocol DocumentParserPort {
    /// Extensiones de archivo soportadas por este parser
    var supportedExtensions: [String] { get }

    /// Extrae secciones de texto de un documento
    /// - Parameter url: URL del archivo a parsear
    /// - Returns: Lista de secciones extraídas del documento
    /// - Throws: Error si falla la lectura o parseo del documento
    func extractSections(from url: URL) async throws -> [DocumentSection]
}
