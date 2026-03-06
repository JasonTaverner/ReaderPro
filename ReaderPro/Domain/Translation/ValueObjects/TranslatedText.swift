import Foundation

/// Value Object que representa texto traducido
/// Contiene el texto traducido y metadatos del idioma
struct TranslatedText: Equatable {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String

    /// Crea texto traducido
    /// - Parameters:
    ///   - originalText: El texto original
    ///   - translatedText: El texto traducido
    ///   - sourceLanguage: Idioma de origen (código ISO 639-1, ej: "es", "en")
    ///   - targetLanguage: Idioma de destino (código ISO 639-1)
    init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    /// Convierte el texto traducido a TextContent del dominio
    /// - Returns: TextContent del dominio con el texto traducido
    /// - Throws: Error si el texto no cumple las validaciones
    func toText() throws -> TextContent {
        try TextContent(translatedText)
    }
}
