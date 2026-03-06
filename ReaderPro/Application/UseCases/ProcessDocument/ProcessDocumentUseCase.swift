import Foundation

/// Caso de uso para procesar documentos PDF y EPUB, extrayendo texto por sección
/// y creando AudioEntries para cada una
final class ProcessDocumentUseCase {

    // MARK: - Dependencies

    private let pdfParser: DocumentParserPort
    private let epubParser: DocumentParserPort
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol

    // MARK: - Initialization

    init(
        pdfParser: DocumentParserPort,
        epubParser: DocumentParserPort,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    ) {
        self.pdfParser = pdfParser
        self.epubParser = epubParser
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
    }

    // MARK: - Execution

    func execute(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse {
        let url = request.documentURL
        let ext = url.pathExtension.lowercased()

        // 1. Select parser based on extension
        let parser: DocumentParserPort
        let documentType: String

        if pdfParser.supportedExtensions.contains(ext) {
            parser = pdfParser
            documentType = "PDF"
        } else if epubParser.supportedExtensions.contains(ext) {
            parser = epubParser
            documentType = "EPUB"
        } else {
            throw DocumentParserError.unsupportedFormat(ext)
        }

        // 2. Extract sections from document
        let sections = try await parser.extractSections(from: url)
        let total = sections.count

        // 3. Save each section as an AudioEntry
        var successfulEntries: [ProcessDocumentResponse.ProcessedSection] = []
        var failedSections: [ProcessDocumentResponse.FailedSection] = []

        for (index, section) in sections.enumerated() {
            do {
                let saveRequest = SaveAudioEntryRequest(
                    projectId: request.projectId,
                    text: section.text
                )
                let saveResponse = try await saveAudioEntryUseCase.execute(saveRequest)

                let preview = String(section.text.prefix(100))
                successfulEntries.append(
                    ProcessDocumentResponse.ProcessedSection(
                        entryId: saveResponse.entryId,
                        entryNumber: saveResponse.entryNumber,
                        title: section.title,
                        textPreview: preview
                    )
                )
            } catch {
                failedSections.append(
                    ProcessDocumentResponse.FailedSection(
                        title: section.title,
                        reason: error.localizedDescription
                    )
                )
            }

            // 4. Report progress
            request.onProgress?(index + 1, total)
        }

        return ProcessDocumentResponse(
            successfulEntries: successfulEntries,
            failedSections: failedSections,
            totalSections: total,
            documentType: documentType
        )
    }
}
