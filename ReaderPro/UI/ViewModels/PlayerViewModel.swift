import Foundation

/// ViewModel para PlayerView
/// Solo contiene estado de UI - sin lógica de negocio
@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: - Published Properties

    /// ID del proyecto que se está reproduciendo
    @Published var projectId: String?

    /// Nombre del proyecto
    @Published var projectName: String = ""

    /// Indica si está reproduciendo
    @Published var isPlaying: Bool = false

    /// Tiempo actual en segundos
    @Published var currentTime: TimeInterval = 0

    /// Duración total en segundos
    @Published var duration: TimeInterval = 0

    /// Velocidad de reproducción (0.5 - 2.0)
    @Published var playbackSpeed: Float = 1.0

    /// Samples para waveform (amplitudes normalizadas 0.0-1.0)
    @Published var waveformSamples: [Float] = []

    /// Indica si está cargando
    @Published var isLoading: Bool = false

    /// Mensaje de error, nil si no hay error
    @Published var error: String?

    // MARK: - Computed Properties

    /// Progreso de reproducción (0.0 - 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    /// Tiempo actual formateado (mm:ss)
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    /// Duración total formateada (mm:ss)
    var durationFormatted: String {
        formatTime(duration)
    }

    /// Indica si hay audio cargado
    var hasAudio: Bool {
        duration > 0
    }

    /// Indica si puede reproducir
    var canPlay: Bool {
        hasAudio && !isLoading
    }

    // MARK: - Private Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
