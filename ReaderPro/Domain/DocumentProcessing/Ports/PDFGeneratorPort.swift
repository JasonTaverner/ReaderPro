import Foundation

/// Port para generación de documentos PDF
/// Define la interfaz que deben implementar los adaptadores de generación de PDF
protocol PDFGeneratorPort {
    /// Genera un PDF a partir de múltiples imágenes (una imagen por página)
    /// - Parameters:
    ///   - imagePaths: Lista de paths a las imágenes (en orden)
    ///   - outputPath: Path donde guardar el PDF resultante
    /// - Returns: Path al archivo PDF generado
    /// - Throws: Error si falla la generación o no hay imágenes
    func generatePDF(from imagePaths: [String], outputPath: String) async throws -> String
}
