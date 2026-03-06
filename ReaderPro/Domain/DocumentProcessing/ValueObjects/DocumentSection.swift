import Foundation

/// Representa una sección de un documento (página de PDF, capítulo de EPUB)
/// Es un Value Object inmutable con validación en construcción
struct DocumentSection: Equatable {
    let title: String
    let text: String
    let pageNumber: Int

    init(title: String, text: String, pageNumber: Int) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.emptyRecognizedText
        }
        guard pageNumber > 0 else {
            throw DomainError.invalidPageNumber
        }
        self.title = title
        self.text = text
        self.pageNumber = pageNumber
    }
}
