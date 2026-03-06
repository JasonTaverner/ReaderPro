import Foundation

/// Errores de infraestructura para el parseo de documentos
enum DocumentParserError: LocalizedError, Equatable {
    case fileNotFound(String)
    case invalidDocument(String)
    case unsupportedFormat(String)
    case noTextContent
    case epubParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Document file not found: \(path)"
        case .invalidDocument(let reason):
            return "Invalid document: \(reason)"
        case .unsupportedFormat(let ext):
            return "Unsupported document format: \(ext)"
        case .noTextContent:
            return "No text content found in document"
        case .epubParsingFailed(let reason):
            return "EPUB parsing failed: \(reason)"
        }
    }
}
