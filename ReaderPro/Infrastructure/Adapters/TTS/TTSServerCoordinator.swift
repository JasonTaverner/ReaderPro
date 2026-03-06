import Foundation
import Combine

/// Coordina múltiples servidores TTS (Kokoro, Qwen3) y gestiona
/// la selección del proveedor activo.
///
/// Responsabilidades:
/// - Mantener referencia a ambos server managers
/// - Permitir al usuario cambiar de proveedor
/// - Arrancar/parar el servidor del proveedor activo
/// - Publicar el estado del servidor activo para la UI
/// - Soportar modo local ONNX para Kokoro (sin servidor Python)
@MainActor
final class TTSServerCoordinator: ObservableObject {

    // MARK: - Kokoro Mode

    /// Modo de ejecución de Kokoro: local (ONNX nativo) o remoto (servidor Python)
    enum KokoroMode: String, CaseIterable {
        case localONNX = "Local (ONNX)"
        case remoteServer = "Server (Python)"

        var displayName: String { rawValue }
    }

    // MARK: - Published State

    /// El proveedor TTS activo seleccionado por el usuario
    @Published var activeProvider: Voice.TTSProvider {
        didSet {
            if oldValue != activeProvider {
                onProviderChanged()
            }
        }
    }

    /// Modo de Kokoro: local ONNX o servidor remoto
    @Published var kokoroMode: KokoroMode = .localONNX {
        didSet {
            if oldValue != kokoroMode && activeProvider == .kokoro {
                onKokoroModeChanged()
            }
        }
    }

    /// Estado del servidor del proveedor activo
    @Published private(set) var activeStatus: TTSServerStatus = .unknown

    // MARK: - Server Managers

    let kokoroManager: KokoroServerManager
    let qwen3Manager: Qwen3ServerManager

    // MARK: - Adapters

    private let nativeAdapter: NativeTTSAdapter
    private let kokoroAdapter: KokoroTTSAdapter
    private let kokoroONNXAdapter: KokoroONNXAdapter?
    private let qwen3Adapter: Qwen3TTSAdapter
    private let adapterProxy: TTSAdapterProxy

    // MARK: - Internal

    private var statusCancellable: AnyCancellable?

    // MARK: - Initialization

    init(
        kokoroManager: KokoroServerManager,
        qwen3Manager: Qwen3ServerManager,
        nativeAdapter: NativeTTSAdapter,
        kokoroAdapter: KokoroTTSAdapter,
        kokoroONNXAdapter: KokoroONNXAdapter?,
        qwen3Adapter: Qwen3TTSAdapter,
        adapterProxy: TTSAdapterProxy,
        initialProvider: Voice.TTSProvider = .kokoro
    ) {
        self.kokoroManager = kokoroManager
        self.qwen3Manager = qwen3Manager
        self.nativeAdapter = nativeAdapter
        self.kokoroAdapter = kokoroAdapter
        self.kokoroONNXAdapter = kokoroONNXAdapter
        self.qwen3Adapter = qwen3Adapter
        self.adapterProxy = adapterProxy
        self.activeProvider = initialProvider

        // Default to local ONNX if available, otherwise remote
        self.kokoroMode = kokoroONNXAdapter != nil ? .localONNX : .remoteServer

        // Set initial adapter
        switch initialProvider {
        case .kokoro:
            if kokoroMode == .localONNX, let onnx = kokoroONNXAdapter {
                adapterProxy.current = onnx
            } else {
                adapterProxy.current = kokoroAdapter
            }
        case .qwen3:
            adapterProxy.current = qwen3Adapter
        case .native:
            adapterProxy.current = nativeAdapter
        }

        // Observe status changes from both managers
        observeActiveStatus()
    }

    // MARK: - Public API

    /// The TTSPort proxy that should be injected into use cases
    var ttsPort: TTSPort {
        adapterProxy
    }

    /// Whether Kokoro local ONNX mode is available
    var isLocalONNXAvailable: Bool {
        kokoroONNXAdapter != nil
    }

    /// Arranca el servidor del proveedor activo
    func startActiveServer() async {
        switch activeProvider {
        case .kokoro:
            if kokoroMode == .localONNX {
                // No server needed for local ONNX
                return
            }
            await kokoroManager.startServer()
        case .qwen3:
            await qwen3Manager.startServer()
        case .native:
            break // No server needed
        }
    }

    /// Para todos los servidores
    func stopAllServers() {
        kokoroManager.stopServer()
        qwen3Manager.stopServer()
    }

    /// Cambia el proveedor y arranca su servidor
    func switchProvider(to provider: Voice.TTSProvider) async {
        activeProvider = provider
        await startActiveServer()
    }

    /// Cambia el modo de Kokoro (local ONNX vs servidor)
    func switchKokoroMode(to mode: KokoroMode) async {
        kokoroMode = mode
        if activeProvider == .kokoro && mode == .remoteServer {
            await kokoroManager.startServer()
        }
    }

    /// Reintenta la conexión del servidor activo
    func retryConnection() async {
        if activeProvider == .kokoro && kokoroMode == .localONNX {
            // For local ONNX, retry means reloading the model
            activeStatus = .starting
            do {
                try kokoroONNXAdapter?.engine.loadModel()
                activeStatus = .connected
            } catch {
                activeStatus = .error(error.localizedDescription)
            }
            return
        }
        await startActiveServer()
    }

    /// Transcribes audio to text using mlx-whisper via the Qwen3 server.
    /// - Parameter url: Local file URL of the audio to transcribe
    /// - Returns: Transcribed text
    func transcribeAudio(url: URL) async throws -> String {
        return try await qwen3Adapter.transcribeAudio(url: url)
    }

    /// Polls the Qwen3 server for generation progress (used during audio generation).
    /// Returns nil if the active provider is not Qwen3 or if the request fails.
    func fetchGenerationProgress() async -> Qwen3TTSAdapter.GenerationProgress? {
        guard activeProvider == .qwen3 else { return nil }
        return await qwen3Adapter.fetchProgress()
    }

    /// Sends a cancel request to the Qwen3 server to abort in-progress generation.
    func cancelGeneration() async -> Bool {
        return await qwen3Adapter.cancelGeneration()
    }

    // MARK: - Private

    private func onProviderChanged() {
        // Stop health polling on the provider we're leaving to avoid idle network noise
        if activeProvider != .kokoro {
            kokoroManager.stopHealthPolling()
        }
        if activeProvider != .qwen3 {
            qwen3Manager.stopHealthPolling()
        }

        // Switch the proxy adapter
        switch activeProvider {
        case .kokoro:
            if kokoroMode == .localONNX, let onnx = kokoroONNXAdapter {
                adapterProxy.current = onnx
            } else {
                adapterProxy.current = kokoroAdapter
            }
        case .qwen3:
            adapterProxy.current = qwen3Adapter
        case .native:
            adapterProxy.current = nativeAdapter
        }

        // Update status observation
        observeActiveStatus()

        print("[TTSCoordinator] Switched to provider: \(activeProvider.displayName)")
    }

    private func onKokoroModeChanged() {
        if kokoroMode == .localONNX, let onnx = kokoroONNXAdapter {
            adapterProxy.current = onnx
            print("[TTSCoordinator] Kokoro switched to Local ONNX mode")
        } else {
            adapterProxy.current = kokoroAdapter
            print("[TTSCoordinator] Kokoro switched to Remote Server mode")
        }
        observeActiveStatus()
    }

    private func observeActiveStatus() {
        statusCancellable?.cancel()

        switch activeProvider {
        case .kokoro:
            if kokoroMode == .localONNX {
                // For local ONNX, status depends on model being loaded
                if let onnx = kokoroONNXAdapter {
                    Task {
                        let available = await onnx.isAvailable
                        self.activeStatus = available ? .connected : .disconnected
                    }
                } else {
                    activeStatus = .disconnected
                }
                statusCancellable = nil
            } else {
                activeStatus = kokoroManager.status
                statusCancellable = kokoroManager.$status
                    .receive(on: RunLoop.main)
                    .sink { [weak self] newStatus in
                        self?.activeStatus = newStatus
                    }
            }
        case .qwen3:
            activeStatus = qwen3Manager.status
            statusCancellable = qwen3Manager.$status
                .receive(on: RunLoop.main)
                .sink { [weak self] newStatus in
                    self?.activeStatus = newStatus
                }
        case .native:
            activeStatus = .connected // Native is always available
            statusCancellable = nil
        }
    }
}
