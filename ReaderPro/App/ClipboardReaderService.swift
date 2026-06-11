import AppKit
import AVFoundation

/// Comando global "leer el portapapeles": sintetiza el texto copiado con el
/// proveedor configurado en Ajustes y lo reproduce. Pulsar el atajo de nuevo
/// detiene la reproducción (toggle).
///
/// Usa un reproductor propio para no interferir con la reproducción de proyectos.
/// Si el proveedor elegido soporta clonación y hay un perfil por defecto en
/// Ajustes, lee con esa voz clonada.
@MainActor
final class ClipboardReaderService: NSObject {

    // MARK: - Settings keys

    static let enabledKey = "clipboardReadEnabled"
    static let hotKeyKey = "clipboardReadHotKey"
    static let providerKey = "clipboardReadProvider"

    // MARK: - Dependencies

    private let coordinator: TTSServerCoordinator
    private let clonedVoiceRepository: ClonedVoiceRepositoryPort

    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?
    private var hotKeyId: UInt32?

    init(coordinator: TTSServerCoordinator, clonedVoiceRepository: ClonedVoiceRepositoryPort) {
        self.coordinator = coordinator
        self.clonedVoiceRepository = clonedVoiceRepository
        super.init()
    }

    // MARK: - Hotkey lifecycle

    /// (Re)registra el atajo global según los ajustes persistidos.
    /// Llamar al arrancar la app y cada vez que cambien los ajustes.
    func applySettings() {
        if let id = hotKeyId {
            GlobalHotKeyManager.shared.unregister(id: id)
            hotKeyId = nil
        }

        let defaults = UserDefaults.standard
        // Activado por defecto (object nil = primera ejecución)
        let enabled = defaults.object(forKey: Self.enabledKey) == nil
            ? true : defaults.bool(forKey: Self.enabledKey)
        guard enabled else {
            print("[ClipboardReader] Global shortcut disabled")
            return
        }

        let comboRaw = defaults.string(forKey: Self.hotKeyKey) ?? GlobalHotKeyCombo.ctrlOptR.rawValue
        let combo = GlobalHotKeyCombo(rawValue: comboRaw) ?? .ctrlOptR

        hotKeyId = GlobalHotKeyManager.shared.register(combo: combo) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.toggleReadClipboard()
            }
        }
    }

    // MARK: - Action

    /// Lee el portapapeles en voz alta; si ya está leyendo, para (toggle)
    func toggleReadClipboard() async {
        // Toggle: si está sonando o sintetizando, parar
        if player?.isPlaying == true || synthesisTask != nil {
            stop()
            return
        }

        guard let raw = NSPasteboard.general.string(forType: .string),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }

        // Respetar el límite del dominio (50k); truncar silenciosamente si excede
        let text = String(raw.prefix(50_000))

        let providerRaw = UserDefaults.standard.string(forKey: Self.providerKey) ?? "supertonic"
        let provider = Voice.TTSProvider(rawValue: providerRaw) ?? .supertonic

        synthesisTask = Task { [weak self] in
            await self?.synthesizeAndPlay(text: text, provider: provider)
            await MainActor.run { [weak self] in self?.synthesisTask = nil }
        }
    }

    func stop() {
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
    }

    // MARK: - Synthesis

    private func synthesizeAndPlay(text: String, provider: Voice.TTSProvider) async {
        await coordinator.ensureServerRunning(for: provider)

        let adapter = coordinator.adapter(for: provider)
        let voices = await adapter.availableVoices()
        guard let voice = voices.first(where: { $0.isDefault }) ?? voices.first else {
            NSSound.beep()
            return
        }

        do {
            let textContent = try TextContent(text)
            let config = try await GlobalCommandVoiceConfig.make(
                provider: provider,
                voiceId: voice.id,
                clonedVoiceRepository: clonedVoiceRepository
            )

            print("[ClipboardReader] Reading \(text.count) chars with \(provider.displayName)")
            let audio = try await adapter.synthesize(
                text: textContent,
                voiceConfiguration: config,
                voice: voice
            )

            try Task.checkCancellation()

            let newPlayer = try AVAudioPlayer(data: audio.data)
            newPlayer.prepareToPlay()
            player = newPlayer
            newPlayer.play()
        } catch is CancellationError {
            // Parado por el usuario
        } catch {
            print("[ClipboardReader] Failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

}
