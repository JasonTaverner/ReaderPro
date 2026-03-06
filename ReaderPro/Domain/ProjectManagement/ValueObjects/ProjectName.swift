import Foundation

/// Value Object que representa el nombre validado de un proyecto
/// - Validación: no vacío, max 100 caracteres
/// - Trimming automático de espacios
/// - Inmutable (struct con let)
struct ProjectName: Equatable {
    let value: String

    /// Crea un ProjectName validado
    /// - Parameter value: El nombre del proyecto a validar
    /// - Throws: DomainError.invalidProjectName si el nombre no cumple las reglas
    init(_ value: String) throws {
        // Validación 1: Trimming automático
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validación 2: No puede estar vacío después de trimming
        guard !trimmed.isEmpty else {
            throw DomainError.invalidProjectName("El nombre no puede estar vacío")
        }

        // Validación 3: No puede exceder 100 caracteres
        guard trimmed.count <= 100 else {
            throw DomainError.invalidProjectName("El nombre excede 100 caracteres")
        }

        self.value = trimmed
    }

    /// Factory method: Crea un ProjectName desde un TextContent
    /// - Toma los primeros 50 caracteres del texto
    /// - Reemplaza saltos de línea con espacios
    /// - Si el resultado está vacío, retorna "Nuevo proyecto"
    /// - Parameter text: El texto fuente
    /// - Returns: Un ProjectName válido
    static func fromText(_ text: TextContent) -> ProjectName {
        // 1. Tomar prefijo de 50 caracteres
        let prefix = String(text.value.prefix(50))

        // 2. Limpiar: reemplazar saltos de línea con espacios
        let cleaned = prefix.replacingOccurrences(of: "\n", with: " ")

        // 3. Trimming
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Si está vacío después de limpiar, usar default
        let finalName = trimmed.isEmpty ? "Nuevo proyecto" : trimmed

        // 5. Force try es seguro aquí porque hemos validado que no está vacío
        // y el límite de 50 caracteres garantiza que no excede 100
        return try! ProjectName(finalName)
    }
}
