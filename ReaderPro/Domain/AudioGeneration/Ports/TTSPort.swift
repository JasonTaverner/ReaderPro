import Foundation

/// Port para servicios de Text-to-Speech
/// Define la interfaz que deben implementar los adaptadores de TTS
/// (NativeTTSAdapter, KokoroTTSAdapter, Qwen3TTSAdapter)
protocol TTSPort {
    /// Indica si el servicio TTS está disponible
    var isAvailable: Bool { get async }

    /// Obtiene las voces disponibles para este proveedor
    /// - Returns: Lista de voces disponibles
    func availableVoices() async -> [Voice]

    /// Sintetiza texto a audio
    /// - Parameters:
    ///   - text: El texto a sintetizar
    ///   - voiceConfiguration: Configuración de voz (velocidad, etc.)
    ///   - voice: La voz a utilizar
    /// - Returns: Los datos de audio generados
    /// - Throws: Error si falla la síntesis
    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData

    /// Obtiene el proveedor de TTS que implementa este port
    var provider: Voice.TTSProvider { get }
}
