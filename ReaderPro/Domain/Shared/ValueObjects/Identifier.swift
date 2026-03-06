import Foundation

/// Value Object genérico que representa un identificador único para Entities
/// - Type-safe: Identifier<Project> != Identifier<AudioEntry>
/// - Basado en UUID para garantizar unicidad
/// - Inmutable (struct con let)
///
/// Uso:
/// ```
/// typealias ProjectId = Identifier<Project>
/// typealias EntryId = Identifier<AudioEntry>
///
/// let projectId = ProjectId()
/// let entryId = EntryId()
/// // projectId y entryId son tipos diferentes y no comparables
/// ```
struct Identifier<T>: Equatable, Hashable, Codable, CustomStringConvertible {
    let value: UUID

    /// Crea un nuevo identificador con un UUID generado automáticamente
    init() {
        self.value = UUID()
    }

    /// Crea un identificador con un UUID específico
    /// Útil para reconstitución desde persistencia
    /// - Parameter value: El UUID a usar
    init(_ value: UUID) {
        self.value = value
    }

    /// Representación en string del identificador
    var description: String {
        value.uuidString
    }
}
