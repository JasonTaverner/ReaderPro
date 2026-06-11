import AppKit
import AVFoundation

/// Comando global "crear entrada desde el portapapeles": crea una entrada nueva
/// con el texto copiado en el proyecto destino configurado y (opcionalmente)
/// genera su audio con el modelo elegido en Ajustes para este comando.
///
/// Destinos: "inbox" (proyecto "Clipboard Inbox", se crea solo la primera vez)
/// o "last" (el último proyecto abierto en el editor).
@MainActor
final class ClipboardEntryService {

    // MARK: - Settings keys

    static let enabledKey = "clipboardEntryEnabled"
    static let hotKeyKey = "clipboardEntryHotKey"
    static let providerKey = "clipboardEntryProvider"
    static let targetKey = "clipboardEntryTarget"          // "inbox" | "last"
    static let generateAudioKey = "clipboardEntryGenerateAudio"
    static let lastOpenedProjectKey = "lastOpenedProjectId"

    static let inboxProjectName = "Clipboard Inbox"

    // MARK: - Dependencies

    private let coordinator: TTSServerCoordinator
    private let clonedVoiceRepository: ClonedVoiceRepositoryPort
    private let projectRepository: ProjectRepositoryPort
    private let createProjectUseCase: CreateProjectUseCaseProtocol
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    private let generateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol

    private var hotKeyId: UInt32?
    private var workTask: Task<Void, Never>?

    init(
        coordinator: TTSServerCoordinator,
        clonedVoiceRepository: ClonedVoiceRepositoryPort,
        projectRepository: ProjectRepositoryPort,
        createProjectUseCase: CreateProjectUseCaseProtocol,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol,
        generateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol
    ) {
        self.coordinator = coordinator
        self.clonedVoiceRepository = clonedVoiceRepository
        self.projectRepository = projectRepository
        self.createProjectUseCase = createProjectUseCase
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
        self.generateAudioForEntryUseCase = generateAudioForEntryUseCase
    }

    // MARK: - Hotkey lifecycle

    func applySettings() {
        if let id = hotKeyId {
            GlobalHotKeyManager.shared.unregister(id: id)
            hotKeyId = nil
        }

        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: Self.enabledKey) == nil
            ? true : defaults.bool(forKey: Self.enabledKey)
        guard enabled else {
            print("[ClipboardEntry] Global shortcut disabled")
            return
        }

        let comboRaw = defaults.string(forKey: Self.hotKeyKey) ?? GlobalHotKeyCombo.ctrlOptL.rawValue
        let combo = GlobalHotKeyCombo(rawValue: comboRaw) ?? .ctrlOptL

        hotKeyId = GlobalHotKeyManager.shared.register(combo: combo) { [weak self] in
            Task { @MainActor [weak self] in
                self?.createEntryFromClipboard()
            }
        }
    }

    // MARK: - Action

    func createEntryFromClipboard() {
        guard workTask == nil else {
            NSSound.beep() // ya hay una creación en curso
            return
        }

        guard let raw = NSPasteboard.general.string(forType: .string),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }

        let text = String(raw.prefix(50_000))

        workTask = Task { [weak self] in
            await self?.performCreate(text: text)
            await MainActor.run { [weak self] in self?.workTask = nil }
        }
    }

    /// Crea una entrada con el texto dado en el proyecto destino configurado.
    /// Reutilizado por el comando de dictado (entrada SIN audio).
    func createEntry(text: String, generateAudio: Bool) async {
        await performCreate(text: text, forceGenerateAudio: generateAudio ? nil : false)
    }

    private func performCreate(text: String, forceGenerateAudio: Bool? = nil) async {
        let defaults = UserDefaults.standard

        do {
            // 1. Resolver el proyecto destino
            let projectId = try await resolveTargetProject()

            // 2. Crear la entrada con el texto del portapapeles
            let request = SaveAudioEntryRequest(projectId: projectId, text: text)
            let response = try await saveAudioEntryUseCase.execute(request)
            print("[ClipboardEntry] Entry \(response.entryNumber) created in project \(projectId.value)")

            // Sonido de confirmación: la entrada ya existe
            NSSound(named: "Pop")?.play()

            // Refrescar el editor si ese proyecto está abierto
            DependencyContainer.shared.makeEditorPresenter()
                .refreshEntriesIfShowing(projectId: projectId.value.uuidString)

            // 3. Generar el audio con el modelo configurado (opcional)
            let settingsGenerate = defaults.object(forKey: Self.generateAudioKey) == nil
                ? true : defaults.bool(forKey: Self.generateAudioKey)
            let generateAudio = forceGenerateAudio ?? settingsGenerate
            guard generateAudio else { return }

            let providerRaw = defaults.string(forKey: Self.providerKey) ?? "supertonic"
            let provider = Voice.TTSProvider(rawValue: providerRaw) ?? .supertonic

            await coordinator.ensureServerRunning(for: provider)
            let adapter = coordinator.adapter(for: provider)
            let voices = await adapter.availableVoices()
            guard let voice = voices.first(where: { $0.isDefault }) ?? voices.first,
                  let entryUUID = UUID(uuidString: response.entryId) else { return }

            let config = try await GlobalCommandVoiceConfig.make(
                provider: provider,
                voiceId: voice.id,
                clonedVoiceRepository: clonedVoiceRepository
            )

            let genRequest = GenerateAudioForEntryRequest(
                projectId: projectId,
                entryId: EntryId(entryUUID),
                voiceConfiguration: config,
                voice: voice
            )
            _ = try await generateAudioForEntryUseCase.execute(genRequest)
            print("[ClipboardEntry] Audio generated for entry \(response.entryId)")

            NSSound(named: "Glass")?.play()
            DependencyContainer.shared.makeEditorPresenter()
                .refreshEntriesIfShowing(projectId: projectId.value.uuidString)

        } catch {
            print("[ClipboardEntry] Failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    // MARK: - Target project

    private func resolveTargetProject() async throws -> Identifier<Project> {
        let defaults = UserDefaults.standard
        let target = defaults.string(forKey: Self.targetKey) ?? "inbox"

        if target == "last",
           let lastId = defaults.string(forKey: Self.lastOpenedProjectKey),
           let uuid = UUID(uuidString: lastId),
           let project = try? await projectRepository.findById(Identifier<Project>(uuid)) {
            return project.id
        }

        // Inbox: buscarlo por nombre, o crearlo la primera vez
        let all = try await projectRepository.findAll()
        if let inbox = all.first(where: { $0.name.value == Self.inboxProjectName }) {
            return inbox.id
        }

        let response = try await createProjectUseCase.execute(
            CreateProjectRequest(name: Self.inboxProjectName)
        )
        print("[ClipboardEntry] Created inbox project")
        return response.projectId
    }
}

/// Configuración de voz compartida por los comandos globales: voz por defecto del
/// proveedor + perfil clonado por defecto de Ajustes si el proveedor lo soporta
enum GlobalCommandVoiceConfig {
    @MainActor
    static func make(
        provider: Voice.TTSProvider,
        voiceId: String,
        clonedVoiceRepository: ClonedVoiceRepositoryPort
    ) async throws -> VoiceConfiguration {
        let defaults = UserDefaults.standard
        let speed = try VoiceConfiguration.Speed(1.0)

        var referenceAudioURL: URL?
        var referenceText: String?

        let supportsCloning = provider == .qwen3 || provider == .voxcpm || provider == .chatterbox
        if supportsCloning,
           let profileId = defaults.string(forKey: SettingsPresenter.defaultCloneProfileIdKey),
           !profileId.isEmpty,
           let profile = try? await clonedVoiceRepository.findById(profileId) {
            referenceAudioURL = clonedVoiceRepository.audioURL(for: profile)
            referenceText = profile.referenceText
        }

        let chatterboxLanguage = defaults.string(forKey: EditorPresenter.chatterboxLanguageKey) ?? "es"
        let supertonicLanguage = defaults.string(forKey: EditorPresenter.supertonicLanguageKey) ?? "es"

        return VoiceConfiguration(
            voiceId: voiceId,
            speed: speed,
            referenceAudioURL: referenceAudioURL,
            referenceText: referenceText,
            chatterboxLanguage: provider == .chatterbox ? chatterboxLanguage : nil,
            supertonicLanguage: provider == .supertonic ? supertonicLanguage : nil
        )
    }
}
