import Foundation

/// Value Object que representa datos de audio generados por TTS
/// - Contiene los bytes de audio y su duración
/// - Validaciones: data no vacío, duration > 0
/// - Inmutable (struct con let)
struct AudioData: Equatable {
    let data: Data
    let duration: TimeInterval

    /// Crea AudioData validado
    /// - Parameters:
    ///   - data: Los bytes del audio (no puede estar vacío)
    ///   - duration: Duración del audio en segundos (debe ser > 0)
    /// - Throws: DomainError si los datos no son válidos
    init(data: Data, duration: TimeInterval) throws {
        // Validación 1: Data no puede estar vacío
        guard !data.isEmpty else {
            throw DomainError.emptyAudioData
        }

        // Validación 2: Duration debe ser mayor a 0
        guard duration > 0 else {
            throw DomainError.invalidAudioDuration("La duración debe ser mayor a 0")
        }

        self.data = data
        self.duration = duration
    }

    /// Tamaño del audio en bytes
    var sizeInBytes: Int {
        data.count
    }

    /// Tamaño del audio en KB
    var sizeInKB: Double {
        Double(sizeInBytes) / 1024.0
    }

    /// Tamaño del audio en MB
    var sizeInMB: Double {
        Double(sizeInBytes) / 1_048_576.0
    }
}
