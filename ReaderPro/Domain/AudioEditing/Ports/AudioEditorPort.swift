import Foundation

/// Port para edición de audio
/// Define la interfaz que deben implementar los adaptadores de edición
/// (AVFoundationEditorAdapter, FFmpegAdapter, etc.)
protocol AudioEditorPort {
    /// Recorta un audio según un rango temporal
    /// - Parameters:
    ///   - audioPath: Path al archivo de audio original
    ///   - timeRange: Rango temporal a extraer
    /// - Returns: Path al archivo de audio recortado
    /// - Throws: Error si falla el recorte
    func trim(audioPath: String, timeRange: TimeRange) async throws -> String

    /// Une múltiples archivos de audio en uno solo
    /// - Parameter audioPaths: Lista de paths a los archivos a unir (en orden)
    /// - Returns: Path al archivo de audio resultante
    /// - Throws: Error si falla la unión o la lista está vacía
    func merge(audioPaths: [String]) async throws -> String

    /// Ajusta la velocidad de reproducción del audio
    /// - Parameters:
    ///   - audioPath: Path al archivo de audio original
    ///   - rate: Factor de velocidad (0.5 = mitad, 2.0 = doble)
    /// - Returns: Path al archivo de audio con velocidad ajustada
    /// - Throws: Error si falla el ajuste
    func adjustSpeed(audioPath: String, rate: Double) async throws -> String

    /// Ajusta el volumen del audio
    /// - Parameters:
    ///   - audioPath: Path al archivo de audio original
    ///   - factor: Factor de volumen (0.5 = mitad, 2.0 = doble)
    /// - Returns: Path al archivo de audio con volumen ajustado
    /// - Throws: Error si falla el ajuste
    func adjustVolume(audioPath: String, factor: Double) async throws -> String

    /// Aplica fade in al inicio del audio
    /// - Parameters:
    ///   - audioPath: Path al archivo de audio original
    ///   - duration: Duración del fade in en segundos
    /// - Returns: Path al archivo de audio con fade in
    /// - Throws: Error si falla el efecto
    func fadeIn(audioPath: String, duration: TimeInterval) async throws -> String

    /// Aplica fade out al final del audio
    /// - Parameters:
    ///   - audioPath: Path al archivo de audio original
    ///   - duration: Duración del fade out en segundos
    /// - Returns: Path al archivo de audio con fade out
    /// - Throws: Error si falla el efecto
    func fadeOut(audioPath: String, duration: TimeInterval) async throws -> String

    /// Obtiene la duración total de un archivo de audio
    /// - Parameter audioPath: Path al archivo de audio
    /// - Returns: Duración en segundos
    /// - Throws: Error si no puede leer el archivo
    func getDuration(audioPath: String) async throws -> TimeInterval

    /// Normaliza el audio (ajusta volumen a nivel óptimo)
    /// - Parameter audioPath: Path al archivo de audio original
    /// - Returns: Path al archivo de audio normalizado
    /// - Throws: Error si falla la normalización
    func normalize(audioPath: String) async throws -> String

    /// Concatena múltiples archivos de audio con silencio entre ellos
    /// - Parameters:
    ///   - audioPaths: Lista de paths a los archivos a concatenar (en orden)
    ///   - silenceDuration: Duración del silencio entre cada archivo en segundos
    ///   - outputPath: Path donde guardar el archivo resultante
    /// - Returns: Path al archivo de audio concatenado
    /// - Throws: Error si falla la concatenación o la lista está vacía
    func concatenate(audioPaths: [String], silenceDuration: TimeInterval, outputPath: String) async throws -> String
}
