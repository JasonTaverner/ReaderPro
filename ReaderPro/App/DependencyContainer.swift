import Foundation

/// Contenedor de inyección de dependencias
/// Crea y conecta todos los componentes de la aplicación
final class DependencyContainer {

    // MARK: - Singleton

    static let shared = DependencyContainer()

    // MARK: - TTS Server Coordinator

    private var _ttsCoordinator: TTSServerCoordinator?

    @MainActor
    var ttsCoordinator: TTSServerCoordinator {
        if let existing = _ttsCoordinator { return existing }

        // Read persisted default provider from UserDefaults
        let providerRaw = UserDefaults.standard.string(forKey: SettingsPresenter.defaultProviderKey) ?? "kokoro"
        let defaultProvider = Voice.TTSProvider(rawValue: providerRaw) ?? .kokoro

        let coordinator = TTSServerCoordinator(
            kokoroManager: kokoroServerManager,
            qwen3Manager: qwen3ServerManager,
            nativeAdapter: nativeTTSAdapter,
            kokoroAdapter: kokoroTTSAdapter,
            kokoroONNXAdapter: kokoroONNXAdapterInstance,
            qwen3Adapter: qwen3TTSAdapter,
            adapterProxy: ttsAdapterProxy,
            initialProvider: defaultProvider
        )

        // Apply persisted Kokoro mode if provider is Kokoro
        let modeRaw = UserDefaults.standard.string(forKey: SettingsPresenter.defaultKokoroModeKey) ?? "localONNX"
        if defaultProvider == .kokoro && modeRaw == "remoteServer" {
            coordinator.kokoroMode = .remoteServer
        }

        _ttsCoordinator = coordinator
        return coordinator
    }

    // MARK: - Server Managers (internal, managed by coordinator)

    private var _kokoroServerManager: KokoroServerManager?

    @MainActor
    var kokoroServerManager: KokoroServerManager {
        if let existing = _kokoroServerManager { return existing }
        let urlString = UserDefaults.standard.string(forKey: SettingsPresenter.kokoroServerURLKey) ?? "http://127.0.0.1:8880"
        let url = URL(string: urlString) ?? URL(string: "http://127.0.0.1:8880")!
        let manager = KokoroServerManager(baseURL: url)
        _kokoroServerManager = manager
        return manager
    }

    private var _qwen3ServerManager: Qwen3ServerManager?

    @MainActor
    var qwen3ServerManager: Qwen3ServerManager {
        if let existing = _qwen3ServerManager { return existing }
        let urlString = UserDefaults.standard.string(forKey: SettingsPresenter.qwen3ServerURLKey) ?? "http://127.0.0.1:8890"
        let url = URL(string: urlString) ?? URL(string: "http://127.0.0.1:8890")!
        let manager = Qwen3ServerManager(baseURL: url)
        _qwen3ServerManager = manager
        return manager
    }

    // MARK: - Configuration

    let storageConfiguration = StorageConfiguration()

    // MARK: - Infrastructure (Adapters)

    private lazy var projectRepository: ProjectRepositoryPort = {
        FileSystemProjectRepository(baseDirectory: storageConfiguration.baseDirectory)
    }()

    private lazy var folderRepository: FolderRepositoryPort = {
        FileSystemFolderRepository(baseDirectory: storageConfiguration.baseDirectory)
    }()

    private lazy var audioStorage: AudioStoragePort = {
        FileSystemAudioStorage(baseDirectory: storageConfiguration.baseDirectory)
    }()

    private lazy var fileStorage: FileStoragePort = {
        FileSystemStorage(baseDirectory: storageConfiguration.baseDirectory)
    }()

    lazy var clonedVoiceRepository: ClonedVoiceRepositoryPort = {
        FileSystemClonedVoiceRepository(baseDirectory: storageConfiguration.baseDirectory)
    }()

    // TTS Adapters
    private lazy var nativeTTSAdapter: NativeTTSAdapter = {
        NativeTTSAdapter()
    }()

    private lazy var kokoroTTSAdapter: KokoroTTSAdapter = {
        let urlString = UserDefaults.standard.string(forKey: SettingsPresenter.kokoroServerURLKey) ?? "http://127.0.0.1:8880"
        let url = URL(string: urlString) ?? URL(string: "http://127.0.0.1:8880")!
        return KokoroTTSAdapter(baseURL: url)
    }()

    private lazy var qwen3TTSAdapter: Qwen3TTSAdapter = {
        let urlString = UserDefaults.standard.string(forKey: SettingsPresenter.qwen3ServerURLKey) ?? "http://127.0.0.1:8890"
        let url = URL(string: urlString) ?? URL(string: "http://127.0.0.1:8890")!
        return Qwen3TTSAdapter(baseURL: url)
    }()

    /// Kokoro ONNX local adapter (nil if resources not available)
    private lazy var kokoroONNXAdapterInstance: KokoroONNXAdapter? = {
        do {
            let engine = try KokoroONNXEngine()
            let phonemizer = try EspeakPhonemizer()
            let tokenizer = KokoroTokenizer()
            let embeddingStore = try VoiceEmbeddingStore()

            return KokoroONNXAdapter(
                engine: engine,
                phonemizer: phonemizer,
                tokenizer: tokenizer,
                embeddingStore: embeddingStore
            )
        } catch {
            print("[DependencyContainer] Kokoro ONNX adapter not available: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Proxy que delega al adapter activo (switchable via coordinator)
    private lazy var ttsAdapterProxy: TTSAdapterProxy = {
        TTSAdapterProxy(kokoroTTSAdapter)
    }()

    /// El TTSPort que se inyecta en todos los use cases
    /// Es un proxy que delega al adapter del proveedor activo
    private lazy var ttsAdapter: TTSPort = {
        ttsAdapterProxy
    }()

    private var _audioPlayer: AudioPlayerPort?

    @MainActor
    var audioPlayer: AudioPlayerPort {
        if let existing = _audioPlayer { return existing }
        let player = AVAudioPlayerAdapter()
        _audioPlayer = player
        return player
    }

    // MARK: - Use Cases

    private lazy var createProjectUseCase: CreateProjectUseCase = {
        CreateProjectUseCase(projectRepository: projectRepository)
    }()

    private lazy var getProjectUseCase: GetProjectUseCase = {
        GetProjectUseCase(projectRepository: projectRepository)
    }()

    private lazy var listProjectsUseCase: ListProjectsUseCase = {
        ListProjectsUseCase(projectRepository: projectRepository)
    }()

    private lazy var updateProjectUseCase: UpdateProjectUseCase = {
        UpdateProjectUseCase(projectRepository: projectRepository)
    }()

    private lazy var deleteProjectUseCase: DeleteProjectUseCase = {
        DeleteProjectUseCase(
            projectRepository: projectRepository,
            audioStorage: audioStorage
        )
    }()

    private lazy var generateAudioUseCase: GenerateAudioUseCase = {
        GenerateAudioUseCase(
            projectRepository: projectRepository,
            ttsPort: ttsAdapter,
            audioStorage: audioStorage
        )
    }()

    private lazy var saveAudioEntryUseCase: SaveAudioEntryUseCase = {
        SaveAudioEntryUseCase(
            projectRepository: projectRepository,
            audioStorage: audioStorage,
            fileStorage: fileStorage
        )
    }()

    private lazy var screenCaptureService: ScreenCapturePort = {
        ScreenCaptureService()
    }()

    private lazy var visionOCRAdapter: OCRPort = {
        VisionOCRAdapter()
    }()

    private lazy var processImageBatchUseCase: ProcessImageBatchUseCase = {
        ProcessImageBatchUseCase(
            ocrPort: visionOCRAdapter,
            ttsPort: ttsAdapter,
            saveAudioEntryUseCase: saveAudioEntryUseCase
        )
    }()

    private lazy var generateAudioForEntryUseCase: GenerateAudioForEntryUseCase = {
        GenerateAudioForEntryUseCase(
            projectRepository: projectRepository,
            ttsPort: ttsAdapter,
            audioStorage: audioStorage
        )
    }()

    private lazy var pdfParserAdapter: PDFParserAdapter = {
        PDFParserAdapter(ocrPort: visionOCRAdapter)
    }()

    private lazy var epubParserAdapter: EPUBParserAdapter = {
        EPUBParserAdapter()
    }()

    private lazy var processDocumentUseCase: ProcessDocumentUseCase = {
        ProcessDocumentUseCase(
            pdfParser: pdfParserAdapter,
            epubParser: epubParserAdapter,
            saveAudioEntryUseCase: saveAudioEntryUseCase
        )
    }()

    private lazy var captureAndProcessUseCase: CaptureAndProcessUseCase = {
        CaptureAndProcessUseCase(
            screenCapturePort: screenCaptureService,
            ocrPort: visionOCRAdapter,
            saveAudioEntryUseCase: saveAudioEntryUseCase,
            ttsPort: ttsAdapter
        )
    }()

    // MARK: - Merge/Export Infrastructure

    private lazy var audioEditorAdapter: AudioEditorPort = {
        AVFoundationEditorAdapter()
    }()

    private lazy var pdfGeneratorAdapter: PDFGeneratorPort = {
        PDFKitGeneratorAdapter()
    }()

    private lazy var mergeProjectUseCase: MergeProjectUseCase = {
        MergeProjectUseCase(
            projectRepository: projectRepository,
            audioEditor: audioEditorAdapter,
            pdfGenerator: pdfGeneratorAdapter,
            fileStorage: fileStorage
        )
    }()

    private lazy var processTextBatchUseCase: ProcessTextBatchUseCase = {
        ProcessTextBatchUseCase(
            projectRepository: projectRepository,
            ttsPort: ttsAdapter,
            saveAudioEntryUseCase: saveAudioEntryUseCase
        )
    }()

    // MARK: - Folder Use Cases

    private lazy var createFolderUseCase: CreateFolderUseCase = {
        CreateFolderUseCase(folderRepository: folderRepository)
    }()

    private lazy var listFoldersUseCase: ListFoldersUseCase = {
        ListFoldersUseCase(folderRepository: folderRepository, projectRepository: projectRepository)
    }()

    private lazy var renameFolderUseCase: RenameFolderUseCase = {
        RenameFolderUseCase(folderRepository: folderRepository)
    }()

    private lazy var deleteFolderUseCase: DeleteFolderUseCase = {
        DeleteFolderUseCase(folderRepository: folderRepository, projectRepository: projectRepository)
    }()

    private lazy var assignProjectToFolderUseCase: AssignProjectToFolderUseCase = {
        AssignProjectToFolderUseCase(projectRepository: projectRepository)
    }()

    // MARK: - Generation Manager

    private var _generationManagerConfigured = false

    @MainActor
    var generationManager: GenerationManager {
        let manager = GenerationManager.shared
        if !_generationManagerConfigured {
            manager.configure(ttsCoordinator: ttsCoordinator)
            _generationManagerConfigured = true
        }
        return manager
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Presenter Factories

    /// Crea un ProjectListPresenter configurado
    @MainActor
    func makeProjectListPresenter() -> ProjectListPresenter {
        ProjectListPresenter(
            listProjectsUseCase: listProjectsUseCase,
            deleteProjectUseCase: deleteProjectUseCase,
            generateAudioUseCase: generateAudioUseCase,
            createProjectUseCase: createProjectUseCase,
            audioStorage: audioStorage,
            projectRepository: projectRepository,
            createFolderUseCase: createFolderUseCase,
            listFoldersUseCase: listFoldersUseCase,
            renameFolderUseCase: renameFolderUseCase,
            deleteFolderUseCase: deleteFolderUseCase,
            assignProjectToFolderUseCase: assignProjectToFolderUseCase
        )
    }

    private var _editorPresenter: EditorPresenter?

    /// Crea un EditorPresenter configurado (Singleton)
    @MainActor
    func makeEditorPresenter() -> EditorPresenter {
        if let existing = _editorPresenter { return existing }
        let presenter = EditorPresenter(
            createProjectUseCase: createProjectUseCase,
            getProjectUseCase: getProjectUseCase,
            updateProjectUseCase: updateProjectUseCase,
            generateAudioUseCase: generateAudioUseCase,
            saveAudioEntryUseCase: saveAudioEntryUseCase,
            captureAndProcessUseCase: captureAndProcessUseCase,
            processImageBatchUseCase: processImageBatchUseCase,
            processDocumentUseCase: processDocumentUseCase,
            generateAudioForEntryUseCase: generateAudioForEntryUseCase,
            mergeProjectUseCase: mergeProjectUseCase,
            processTextBatchUseCase: processTextBatchUseCase,
            ttsPort: ttsAdapter,
            audioPlayer: audioPlayer,
            audioStorage: audioStorage,
            ttsCoordinator: ttsCoordinator,
            clonedVoiceRepository: clonedVoiceRepository,
            generationManager: generationManager
        )
        _editorPresenter = presenter
        return presenter
    }

    /// Crea un PlayerPresenter configurado
    @MainActor
    func makePlayerPresenter() -> PlayerPresenter {
        PlayerPresenter(
            getProjectUseCase: getProjectUseCase,
            audioPlayer: audioPlayer,
            audioStorage: audioStorage
        )
    }

    /// Crea un SettingsPresenter configurado
    @MainActor
    func makeSettingsPresenter() -> SettingsPresenter {
        SettingsPresenter(
            storageConfiguration: storageConfiguration,
            qwen3Adapter: qwen3TTSAdapter,
            ttsCoordinator: ttsCoordinator,
            clonedVoiceRepository: clonedVoiceRepository
        )
    }
}
