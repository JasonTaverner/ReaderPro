import Foundation
import AppKit
import Combine

/// Presenter para la pantalla de Settings
/// Coordina la configuración de almacenamiento y TTS model management
@MainActor
final class SettingsPresenter: ObservableObject {

    // MARK: - Published Properties

    /// ViewModel que la View observa
    @Published private(set) var viewModel = SettingsViewModel()

    // MARK: - Dependencies

    private let storageConfiguration: StorageConfiguration
    private let qwen3Adapter: Qwen3TTSAdapter
    private let ttsCoordinator: TTSServerCoordinator?
    private let clonedVoiceRepository: ClonedVoiceRepositoryPort?

    /// Subscription for status changes
    private var statusCancellable: AnyCancellable?

    /// Propagates nested viewModel changes to the presenter's objectWillChange
    private var viewModelCancellable: AnyCancellable?

    // MARK: - UserDefaults Keys

    static let defaultProviderKey = "defaultTTSProvider"
    static let defaultKokoroModeKey = "defaultKokoroMode"
    static let kokoroServerURLKey = "kokoroServerURL"
    static let qwen3ServerURLKey = "qwen3ServerURL"
    static let defaultQwen3AccentKey = "defaultQwen3Accent"
    static let defaultQwen3EmotionKey = "defaultQwen3Emotion"
    static let defaultQwen3GenderKey = "defaultQwen3Gender"
    static let defaultCloneAccentKey = "defaultCloneAccent"
    static let defaultCloneEnabledKey = "defaultCloneEnabled"
    static let defaultCloneProfileIdKey = "defaultCloneProfileId"

    // MARK: - Initialization

    init(
        storageConfiguration: StorageConfiguration,
        qwen3Adapter: Qwen3TTSAdapter,
        ttsCoordinator: TTSServerCoordinator? = nil,
        clonedVoiceRepository: ClonedVoiceRepositoryPort? = nil
    ) {
        self.storageConfiguration = storageConfiguration
        self.qwen3Adapter = qwen3Adapter
        self.ttsCoordinator = ttsCoordinator
        self.clonedVoiceRepository = clonedVoiceRepository

        // Propagate nested viewModel changes so SwiftUI re-renders
        viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Observe status changes from coordinator
        if let coordinator = ttsCoordinator {
            statusCancellable = coordinator.$activeStatus
                .receive(on: RunLoop.main)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    if status == .connected && coordinator.activeProvider == .qwen3 {
                        Task { await self.refreshModelStatus() }
                    } else if status == .disconnected || status == .error("") {
                        self.viewModel.isServerOnline = false
                        self.viewModel.loadedModelName = nil
                    }
                }
        }
    }

    // MARK: - View Lifecycle

    /// Llamado cuando la vista aparece
    func onAppear() {
        loadCurrentDirectory()
        loadClonedVoicesInfo()
        loadDefaultProviderSettings()
        Task {
            await refreshModelStatus()
        }
    }

    // MARK: - Storage Actions

    /// Abre NSOpenPanel para seleccionar un nuevo directorio de almacenamiento
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a directory for storing ReaderPro projects"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try storageConfiguration.setBaseDirectory(url)
            loadCurrentDirectory()
            viewModel.showRestartAlert = true
        } catch {
            viewModel.error = "Failed to set directory: \(error.localizedDescription)"
        }
    }

    /// Resetea al directorio por defecto
    func resetToDefault() {
        storageConfiguration.resetToDefault()
        loadCurrentDirectory()
        viewModel.showRestartAlert = true
    }

    // MARK: - TTS Model Actions

    /// Refresh the current model status from the server
    func refreshModelStatus() async {
        do {
            let status = try await qwen3Adapter.fetchModelStatus()
            viewModel.isServerOnline = true
            viewModel.loadedModelName = status.loadedModel
        } catch {
            viewModel.isServerOnline = false
            viewModel.loadedModelName = nil
        }
    }

    /// Unload the current model to free memory
    func unloadModel() async {
        viewModel.isModelOperationInProgress = true
        defer { viewModel.isModelOperationInProgress = false }

        do {
            _ = try await qwen3Adapter.unloadModel()
            await refreshModelStatus()
        } catch {
            viewModel.error = "Failed to unload model: \(error.localizedDescription)"
        }
    }

    // MARK: - Cloned Voices Actions

    /// Opens the cloned voices directory in Finder
    func openClonedVoicesInFinder() {
        guard let repo = clonedVoiceRepository else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.baseDirectory.path)
    }

    // MARK: - Private Methods

    private func loadClonedVoicesInfo() {
        guard let repo = clonedVoiceRepository else { return }
        viewModel.clonedVoicesDirectoryPath = repo.baseDirectory.path
        Task {
            let profiles = try? await repo.findAll()
            viewModel.clonedVoicesCount = profiles?.count ?? 0
        }
    }

    private func loadClonedVoiceProfilesList() {
        guard let repo = clonedVoiceRepository else { return }
        Task {
            let profiles = (try? await repo.findAll()) ?? []
            viewModel.clonedVoiceProfiles = profiles.map { ClonedVoiceProfileDTO(from: $0) }
        }
    }

    private func loadCurrentDirectory() {
        viewModel.currentDirectoryPath = storageConfiguration.baseDirectory.path
        viewModel.isCustomDirectory = storageConfiguration.isCustomDirectory
    }

    // MARK: - Default Provider Settings

    private func loadDefaultProviderSettings() {
        viewModel.defaultProvider = UserDefaults.standard.string(forKey: Self.defaultProviderKey) ?? "kokoro"
        viewModel.defaultKokoroMode = UserDefaults.standard.string(forKey: Self.defaultKokoroModeKey) ?? "localONNX"
        viewModel.kokoroServerURL = UserDefaults.standard.string(forKey: Self.kokoroServerURLKey) ?? "http://127.0.0.1:8880"
        viewModel.qwen3ServerURL = UserDefaults.standard.string(forKey: Self.qwen3ServerURLKey) ?? "http://127.0.0.1:8890"
        viewModel.defaultQwen3Accent = UserDefaults.standard.string(forKey: Self.defaultQwen3AccentKey) ?? ""
        viewModel.defaultQwen3Emotion = UserDefaults.standard.string(forKey: Self.defaultQwen3EmotionKey) ?? "neutral"
        viewModel.defaultQwen3Gender = UserDefaults.standard.string(forKey: Self.defaultQwen3GenderKey) ?? "female"

        // Clone defaults (fast mode/model use same keys as EditorPresenter)
        viewModel.defaultCloneFastMode = UserDefaults.standard.bool(forKey: EditorPresenter.cloneFastModeKey)
        viewModel.defaultCloneFastModel = UserDefaults.standard.bool(forKey: EditorPresenter.cloneFastModelKey)
        viewModel.defaultCloneAccent = UserDefaults.standard.string(forKey: Self.defaultCloneAccentKey) ?? ""
        viewModel.defaultCloneEnabled = UserDefaults.standard.bool(forKey: Self.defaultCloneEnabledKey)
        viewModel.defaultCloneProfileId = UserDefaults.standard.string(forKey: Self.defaultCloneProfileIdKey) ?? ""

        // Load cloned voice profiles for the picker
        loadClonedVoiceProfilesList()
    }

    func setDefaultProvider(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultProviderKey)
        viewModel.defaultProvider = value
    }

    func setDefaultKokoroMode(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultKokoroModeKey)
        viewModel.defaultKokoroMode = value
    }

    func setKokoroServerURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.kokoroServerURLKey)
        viewModel.kokoroServerURL = value
    }

    func setQwen3ServerURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.qwen3ServerURLKey)
        viewModel.qwen3ServerURL = value
    }

    func setDefaultQwen3Accent(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultQwen3AccentKey)
        viewModel.defaultQwen3Accent = value
    }

    func setDefaultQwen3Emotion(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultQwen3EmotionKey)
        viewModel.defaultQwen3Emotion = value
    }

    func setDefaultQwen3Gender(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultQwen3GenderKey)
        viewModel.defaultQwen3Gender = value
    }

    func setDefaultCloneFastMode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: EditorPresenter.cloneFastModeKey)
        viewModel.defaultCloneFastMode = value
    }

    func setDefaultCloneFastModel(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: EditorPresenter.cloneFastModelKey)
        viewModel.defaultCloneFastModel = value
    }

    func setDefaultCloneAccent(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultCloneAccentKey)
        viewModel.defaultCloneAccent = value
    }

    func setDefaultCloneEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.defaultCloneEnabledKey)
        viewModel.defaultCloneEnabled = value
    }

    func setDefaultCloneProfileId(_ value: String) {
        UserDefaults.standard.set(value, forKey: Self.defaultCloneProfileIdKey)
        viewModel.defaultCloneProfileId = value
    }
}
