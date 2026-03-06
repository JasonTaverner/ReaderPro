import Foundation

/// Port para reproducción de audio
/// Define la interfaz que deben implementar los adaptadores de reproducción
/// (AVFoundationPlayerAdapter, etc.)
protocol AudioPlayerPort {
    /// Tiempo actual de reproducción en segundos
    var currentTime: TimeInterval { get }

    /// Duración total del audio actual en segundos
    var duration: TimeInterval { get }

    /// Indica si está reproduciendo
    var isPlaying: Bool { get }

    /// Velocidad de reproducción actual
    var rate: Float { get }

    /// Callback que se invoca cuando el audio termina de reproducirse
    var onPlaybackComplete: (() -> Void)? { get set }

    /// Carga un archivo de audio para reproducir
    /// - Parameter path: Path al archivo de audio
    /// - Throws: Error si no puede cargar el archivo
    func load(path: String) async throws

    /// Inicia o reanuda la reproducción
    func play() async

    /// Pausa la reproducción
    func pause() async

    /// Detiene la reproducción y resetea la posición
    func stop() async

    /// Busca a una posición específica en el audio
    /// - Parameter time: Tiempo en segundos
    func seek(to time: TimeInterval) async

    /// Configura la velocidad de reproducción
    /// - Parameter rate: Velocidad (0.5 - 2.0)
    func setRate(_ rate: Float) async

    /// Genera samples de waveform para visualización
    /// - Parameter sampleCount: Número de samples a generar
    /// - Returns: Array de amplitudes normalizadas
    func generateWaveformSamples(sampleCount: Int) async throws -> [Float]
}

/// Estado de reproducción del audio
enum PlaybackState: Equatable {
    case idle       // Sin audio cargado
    case ready      // Audio cargado, listo para reproducir
    case playing    // Reproduciendo
    case paused     // Pausado
    case stopped    // Detenido
    case error      // Error en reproducción
}
