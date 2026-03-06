import Foundation
import PDFKit

/// Adaptador para parsear documentos PDF usando PDFKit
/// Extrae texto por página, con fallback a OCR para PDFs escaneados
final class PDFParserAdapter: DocumentParserPort {

    // MARK: - Dependencies

    private let ocrPort: OCRPort

    // MARK: - Initialization

    init(ocrPort: OCRPort) {
        self.ocrPort = ocrPort
    }

    // MARK: - DocumentParserPort

    var supportedExtensions: [String] { ["pdf"] }

    func extractSections(from url: URL) async throws -> [DocumentSection] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound(url.path)
        }

        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentParserError.invalidDocument("Could not open PDF file")
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw DocumentParserError.noTextContent
        }

        var sections: [DocumentSection] = []

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            let pageNumber = pageIndex + 1
            let title = "Page \(pageNumber)"

            // Try direct text extraction first
            var pageText = page.string ?? ""
            pageText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Fallback to OCR if no selectable text
            if pageText.isEmpty {
                do {
                    let recognizedText = try await ocrPort.recognizeText(
                        from: url.path,
                        pageNumber: pageNumber
                    )
                    pageText = recognizedText.text
                } catch {
                    // Skip pages where both text extraction and OCR fail
                    continue
                }
            }

            // Skip pages with no text content
            guard !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                let section = try DocumentSection(
                    title: title,
                    text: pageText,
                    pageNumber: pageNumber
                )
                sections.append(section)
            } catch {
                // Skip sections that fail validation
                continue
            }
        }

        guard !sections.isEmpty else {
            throw DocumentParserError.noTextContent
        }

        return sections
    }
}
