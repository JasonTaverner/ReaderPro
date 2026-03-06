import Foundation

/// Value Object que representa texto validado para TTS
/// - Validación: no vacío, max 6000 caracteres
/// - Calcula número de palabras y duración estimada
/// - Inmutable (struct con let)
struct TextContent: Equatable {
    let value: String

    /// Crea un TextContent validado
    /// - Parameter value: El texto a validar
    /// - Throws: DomainError.invalidText si el texto no cumple las reglas
    init(_ value: String) throws {
        // Validación 1: No puede estar vacío después de quitar espacios
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.invalidText("El texto no puede estar vacío")
        }

        // Validación 2: No puede exceder 6000 caracteres
        guard value.count <= 6000 else {
            throw DomainError.invalidText("El texto excede el límite de 6000 caracteres")
        }

        self.value = value
    }

    /// Número de palabras en el texto
    /// Cuenta elementos separados por espacios/saltos de línea
    var wordCount: Int {
        let components = value.components(separatedBy: .whitespacesAndNewlines)
        let words = components.filter { !$0.isEmpty }
        return words.count
    }

    /// Duración estimada del audio en segundos
    /// Basado en ~150 palabras por minuto (velocidad promedio de lectura en español)
    var estimatedDuration: TimeInterval {
        let wordsPerMinute = 150.0
        let minutes = Double(wordCount) / wordsPerMinute
        let seconds = minutes * 60.0
        return seconds
    }
}
