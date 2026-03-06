import Foundation

/// Value Object que representa un rango de tiempo para edición de audio
/// - start: tiempo de inicio (>= 0)
/// - end: tiempo de fin (> start)
/// - Inmutable (struct con let)
struct TimeRange: Equatable {
    let start: TimeInterval
    let end: TimeInterval

    /// Duración del rango en segundos
    var duration: TimeInterval {
        end - start
    }

    /// Crea un TimeRange validado
    /// - Parameters:
    ///   - start: Tiempo de inicio (debe ser >= 0)
    ///   - end: Tiempo de fin (debe ser > start)
    /// - Throws: DomainError.invalidTimeRange si no cumple las reglas
    init(start: TimeInterval, end: TimeInterval) throws {
        // Validación 1: Start debe ser >= 0
        guard start >= 0 else {
            throw DomainError.invalidTimeRange("Start debe ser >= 0")
        }

        // Validación 2: End debe ser > start
        guard end > start else {
            throw DomainError.invalidTimeRange("End debe ser > start")
        }

        self.start = start
        self.end = end
    }

    /// Verifica si un tiempo específico está contenido en este rango
    /// - Parameter time: El tiempo a verificar
    /// - Returns: true si el tiempo está en el rango [start, end] (inclusive)
    func contains(_ time: TimeInterval) -> Bool {
        (start...end).contains(time)
    }

    /// Verifica si este rango se solapa con otro rango
    /// Dos rangos se solapan si comparten al menos un punto en común
    /// - Parameter other: El otro rango a verificar
    /// - Returns: true si los rangos se solapan
    func overlaps(with other: TimeRange) -> Bool {
        // Condición de solapamiento:
        // Dos rangos se solapan si comparten al menos un punto.
        // Rangos adyacentes (ej: [2,5] y [5,8]) SÍ se solapan en el punto común.
        start <= other.end && end >= other.start
    }
}
