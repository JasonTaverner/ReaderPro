import Foundation
import Combine

/// Presenter para el reproductor de audio
/// Coordina la reproducción y actualización del estado
@MainActor
final class PlayerPresenter: ObservableObject {

    // MARK: - Published Properties

    /// ViewModel que la View observa
    @Published private(set) var viewModel = PlayerViewModel()

    // MARK: - Dependencies

    private let getProjectUseCase: GetProjectUseCaseProtocol
    private let audioPlayer: AudioPlayerPort
    private let audioStorage: AudioStoragePort

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private let skipInterval: TimeInterval = 10.0

    // MARK: - Initialization

    init(
        getProjectUseCase: GetProjectUseCaseProtocol,
        audioPlayer: AudioPlayerPort,
        audioStorage: AudioStoragePort
    ) {
        self.getProjectUseCase = getProjectUseCase
        self.audioPlayer = audioPlayer
        self.audioStorage = audioStorage
    }

    // MARK: - View Lifecycle

    /// Llamado cuando la vista aparece
    /// - Parameter projectId: ID del proyecto a reproducir
    func onAppear(projectId: Identifier<Project>) async {
        viewModel.isLoading = true
        viewModel.error = nil

        do {
            // 1. Cargar proyecto (con reintento si no tiene audio)
            print("[PlayerPresenter] Loading project: \(projectId.value)")
            let request = GetProjectRequest(projectId: projectId)
            var response = try await getProjectUseCase.execute(request)

            viewModel.projectId = projectId.value.uuidString
            viewModel.projectName = response.name
            print("[PlayerPresenter] Project loaded: \(response.name)")

            // 2. Verificar que tenga audio (con reintento)
            var audioPath = response.audioPath
            print("[PlayerPresenter] Audio path from project: \(audioPath ?? "nil")")
            if audioPath == nil || audioPath!.isEmpty {
                // Esperar un momento y reintentar (por si el audio acaba de generarse)
                print("[PlayerPresenter] No audio path, retrying in 0.5s...")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
                response = try await getProjectUseCase.execute(request)
                audioPath = response.audioPath
                print("[PlayerPresenter] Retry audio path: \(audioPath ?? "nil")")
            }

            guard let finalAudioPath = audioPath, !finalAudioPath.isEmpty else {
                print("[PlayerPresenter] ERROR: No audio path available")
                viewModel.error = "This project has no audio. Generate audio first."
                viewModel.isLoading = false
                return
            }

            // 3. Cargar audio en el player
            // Use URL-based path construction for correctness
            let baseURL = URL(fileURLWithPath: audioStorage.baseDirectory, isDirectory: true)
            let fullURL = baseURL.appendingPathComponent(finalAudioPath)
            let fullPath = fullURL.path
            print("[PlayerPresenter] Base directory: \(audioStorage.baseDirectory)")
            print("[PlayerPresenter] Audio filename: \(finalAudioPath)")
            print("[PlayerPresenter] Full audio path: \(fullPath)")
            print("[PlayerPresenter] File exists: \(FileManager.default.fileExists(atPath: fullPath))")

            // List files in base directory for debugging
            if !FileManager.default.fileExists(atPath: fullPath) {
                let contents = (try? FileManager.default.contentsOfDirectory(atPath: audioStorage.baseDirectory)) ?? []
                let wavFiles = contents.filter { $0.hasSuffix(".wav") }
                print("[PlayerPresenter] WAV files in base dir: \(wavFiles)")
            }

            try await audioPlayer.load(path: fullPath)
            print("[PlayerPresenter] Audio loaded successfully")

            // 4. Obtener duración
            viewModel.duration = audioPlayer.duration
            print("[PlayerPresenter] Duration: \(viewModel.duration)s")

            // 5. Generar waveform (en background para no bloquear UI)
            print("[PlayerPresenter] Generating waveform...")
            try await generateWaveform()
            print("[PlayerPresenter] Waveform generated")

            // 6. Iniciar timer de actualización
            startUpdateTimer()

        } catch {
            print("[PlayerPresenter] ERROR: \(error.localizedDescription)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isLoading = false
    }

    /// Llamado cuando la vista desaparece
    func onDisappear() async {
        stopUpdateTimer()
        await audioPlayer.stop()
    }

    // MARK: - Playback Controls

    /// Inicia la reproducción
    func play() async {
        await audioPlayer.play()
        updatePlaybackState()
    }

    /// Pausa la reproducción
    func pause() async {
        await audioPlayer.pause()
        updatePlaybackState()
    }

    /// Toggle play/pause
    func togglePlayPause() async {
        if viewModel.isPlaying {
            await pause()
        } else {
            await play()
        }
    }

    /// Busca a una posición específica (0.0 - 1.0)
    /// - Parameter progress: Progreso normalizado
    func seek(to progress: Double) async {
        let clampedProgress = max(0, min(1.0, progress))
        let targetTime = clampedProgress * viewModel.duration
        await audioPlayer.seek(to: targetTime)
        updatePlaybackState()
    }

    /// Salta 10 segundos hacia atrás
    func skipBackward() async {
        let newTime = max(0, viewModel.currentTime - skipInterval)
        await audioPlayer.seek(to: newTime)
        updatePlaybackState()
    }

    /// Salta 10 segundos hacia adelante
    func skipForward() async {
        let newTime = min(viewModel.duration, viewModel.currentTime + skipInterval)
        await audioPlayer.seek(to: newTime)
        updatePlaybackState()
    }

    /// Configura la velocidad de reproducción
    /// - Parameter speed: Velocidad (0.5 - 2.0)
    func setSpeed(_ speed: Float) async {
        let clampedSpeed = max(0.5, min(2.0, speed))
        await audioPlayer.setRate(clampedSpeed)
        viewModel.playbackSpeed = audioPlayer.rate
    }

    /// Actualiza el estado de reproducción desde el AudioPlayer
    func updatePlaybackState() {
        let newTime = audioPlayer.currentTime
        let newPlaying = audioPlayer.isPlaying
        if abs(viewModel.currentTime - newTime) > 0.05 {
            viewModel.currentTime = newTime
        }
        if viewModel.isPlaying != newPlaying {
            viewModel.isPlaying = newPlaying
        }
    }

    // MARK: - Private Methods

    /// Genera samples para el waveform
    private func generateWaveform() async throws {
        let sampleCount = 200 // Número de samples para la visualización
        let samples = try await audioPlayer.generateWaveformSamples(sampleCount: sampleCount)
        viewModel.waveformSamples = samples
    }

    /// Inicia el timer para actualizar el estado de reproducción
    private func startUpdateTimer() {
        stopUpdateTimer()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.audioPlayer.isPlaying {
                    if self.viewModel.isPlaying {
                        self.viewModel.isPlaying = false
                    }
                    self.stopUpdateTimer()
                    return
                }
                self.updatePlaybackState()
            }
        }
    }

    /// Detiene el timer de actualización
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
