import Foundation

/// Value Object que representa texto reconocido por OCR
/// Contiene el texto extraído y metadatos de confianza
struct RecognizedText: Equatable {
    let text: String
    let confidence: Double  // 0.0 a 1.0
    let language: String?   // Idioma detectado (opcional)

    /// Crea texto reconocido
    /// - Parameters:
    ///   - text: El texto extraído
    ///   - confidence: Nivel de confianza (0.0 a 1.0)
    ///   - language: Idioma detectado (opcional)
    /// - Throws: DomainError si los valores son inválidos
    init(text: String, confidence: Double, language: String? = nil) throws {
        guard !text.isEmpty else {
            throw DomainError.emptyRecognizedText
        }
        guard (0.0...1.0).contains(confidence) else {
            throw DomainError.invalidConfidence
        }
        self.text = text
        self.confidence = confidence
        self.language = language
    }

    /// Indica si el reconocimiento tiene alta confianza (>= 0.8)
    var hasHighConfidence: Bool {
        confidence >= 0.8
    }

    /// Convierte el texto reconocido a TextContent del dominio
    /// - Returns: TextContent del dominio
    /// - Throws: Error si el texto no cumple las validaciones de TextContent
    func toText() throws -> TextContent {
        try TextContent(text)
    }
}
