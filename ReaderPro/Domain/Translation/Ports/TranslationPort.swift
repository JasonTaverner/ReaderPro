import Foundation

/// Port para servicios de traducción
/// Define la interfaz que deben implementar los adaptadores de traducción
/// (OpenAITranslationAdapter, GoogleTranslateAdapter, DeepLAdapter, etc.)
protocol TranslationPort {
    /// Indica si el servicio de traducción está disponible
    var isAvailable: Bool { get async }

    /// Traduce texto de un idioma a otro
    /// - Parameters:
    ///   - text: El texto a traducir (domain TextContent)
    ///   - sourceLanguage: Idioma de origen (código ISO 639-1, ej: "es")
    ///   - targetLanguage: Idioma de destino (código ISO 639-1, ej: "en")
    /// - Returns: El texto traducido con metadatos
    /// - Throws: Error si falla la traducción
    func translate(
        text: TextContent,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> TranslatedText

    /// Detecta automáticamente el idioma del texto y lo traduce
    /// - Parameters:
    ///   - text: El texto a traducir
    ///   - targetLanguage: Idioma de destino
    /// - Returns: El texto traducido con idioma de origen detectado
    /// - Throws: Error si falla la detección o traducción
    func translateWithAutoDetection(
        text: TextContent,
        to targetLanguage: String
    ) async throws -> TranslatedText

    /// Detecta el idioma de un texto
    /// - Parameter text: El texto a analizar
    /// - Returns: Código de idioma detectado (ISO 639-1)
    /// - Throws: Error si falla la detección
    func detectLanguage(text: TextContent) async throws -> String

    /// Idiomas soportados por el servicio
    /// - Returns: Lista de códigos de idioma soportados (ISO 639-1)
    var supportedLanguages: [String] { get async }
}
