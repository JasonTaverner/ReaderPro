import Foundation
import PDFKit
import AppKit

/// Adaptador que implementa PDFGeneratorPort usando PDFKit
/// Genera documentos PDF a partir de imágenes (una imagen por página)
final class PDFKitGeneratorAdapter: PDFGeneratorPort {

    // MARK: - PDFGeneratorPort Implementation

    func generatePDF(from imagePaths: [String], outputPath: String) async throws -> String {
        guard !imagePaths.isEmpty else {
            throw PDFGeneratorError.noImages
        }

        // Crear documento PDF
        let pdfDocument = PDFDocument()

        // Añadir cada imagen como una página
        for (index, imagePath) in imagePaths.enumerated() {
            let imageURL = URL(fileURLWithPath: imagePath)

            guard FileManager.default.fileExists(atPath: imagePath) else {
                throw PDFGeneratorError.imageNotFound(imagePath)
            }

            guard let image = NSImage(contentsOf: imageURL) else {
                throw PDFGeneratorError.invalidImage(imagePath)
            }

            // Crear página PDF desde la imagen
            guard let pdfPage = PDFPage(image: image) else {
                throw PDFGeneratorError.pageCreationFailed(imagePath)
            }

            pdfDocument.insert(pdfPage, at: index)
        }

        // Asegurar que el directorio padre existe
        let outputURL = URL(fileURLWithPath: outputPath)
        let parentDirectory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDirectory,
            withIntermediateDirectories: true
        )

        // Guardar PDF
        guard pdfDocument.write(to: outputURL) else {
            throw PDFGeneratorError.writeFailed(outputPath)
        }

        return outputPath
    }
}

// MARK: - Errors

enum PDFGeneratorError: LocalizedError {
    case noImages
    case imageNotFound(String)
    case invalidImage(String)
    case pageCreationFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImages:
            return "No hay imágenes para generar el PDF"
        case .imageNotFound(let path):
            return "Imagen no encontrada: \(path)"
        case .invalidImage(let path):
            return "Imagen inválida: \(path)"
        case .pageCreationFailed(let path):
            return "Error al crear página para: \(path)"
        case .writeFailed(let path):
            return "Error al guardar PDF en: \(path)"
        }
    }
}
