import Foundation

/// State for auto-save indicator
enum SaveState: Equatable {
    case idle       // No changes pending
    case pending    // Changes pending, timer running
    case saving     // Actively saving
    case saved      // Recently saved successfully
}

/// ViewModel para EditorView
/// Solo contiene estado de UI - sin lógica de negocio
@MainActor
final class EditorViewModel: ObservableObject {

    // MARK: - Auto-Save State

    /// Current auto-save state for UI indicator
    @Published var autoSaveState: SaveState = .idle

    // MARK: - Published Properties

    /// ID del proyecto (nil si es nuevo)
    @Published var projectId: String?

    /// Nombre de la carpeta del proyecto en disco
    @Published var folderName: String?

    /// Nombre del proyecto
    @Published var name: String = ""

    /// Texto del proyecto
    @Published var text: String = ""

    /// ID de la voz seleccionada
    @Published var selectedVoiceId: String?

    /// Voces disponibles
    @Published var availableVoices: [VoiceDTO] = []

    /// Velocidad de la voz (0.5 - 2.0)
    @Published var speed: Double = 1.0

    /// Indica si está cargando datos
    @Published var isLoading: Bool = false

    /// Indica si está generando audio
    @Published var isGenerating: Bool = false

    /// Active TTS provider rawValue ("kokoro" or "qwen3")
    @Published var activeProvider: String = "kokoro"

    /// Mensaje de error, nil si no hay error
    @Published var error: String?

    /// Duración estimada del audio
    @Published var estimatedDuration: String = "0:00"

    /// Indica si el audio se generó correctamente (para mostrar alerta de éxito)
    @Published var showAudioGeneratedSuccess: Bool = false

    /// Duración real del audio generado
    @Published var generatedAudioDuration: String?

    /// Indica si el proyecto se guardó correctamente
    @Published var showSaveSuccess: Bool = false

    /// Indica si el proyecto tiene audio (cargado o generado)
    @Published var audioPath: String?

    // MARK: - Playback State

    /// Indica si está reproduciendo audio
    @Published var isPlaying: Bool = false

    /// Tiempo actual de reproducción en segundos
    @Published var currentTime: TimeInterval = 0

    /// Duración total del audio en segundos
    @Published var audioDuration: TimeInterval = 0

    /// Velocidad de reproducción (0.5 - 2.0)
    @Published var playbackSpeed: Float = 1.0

    /// Samples para visualización de waveform
    @Published var waveformSamples: [Float] = []

    // MARK: - Audio Entries

    /// Lista de audio entries del proyecto
    @Published var entries: [AudioEntryDTO] = []

    /// ID del entry actualmente reproduciéndose
    @Published var playingEntryId: String?

    // MARK: - Entry Tabs

    /// Selected entry tab: nil = project text, String = entry id
    @Published var selectedEntryTab: String? = nil

    /// Cache of edited entry texts, keyed by entry id
    @Published var entryTexts: [String: String] = [:]

    // MARK: - Auto-Play State

    /// Indica si el auto-play está habilitado (reproducir siguiente automáticamente)
    @Published var isAutoPlayEnabled: Bool = false

    /// Índice del entry actualmente reproduciéndose (-1 si no hay ninguno)
    @Published var currentPlayingIndex: Int = -1

    // MARK: - Qwen3 Emotion / Voice Cloning State

    /// Selected emotion preset (SpeechEmotion rawValue)
    @Published var selectedEmotion: String = "neutral"

    /// Custom instruct text (overrides emotion preset when non-empty)
    @Published var customInstruct: String = ""

    /// Reference audio URL for voice cloning
    @Published var referenceAudioURL: URL? = nil

    /// Transcript of the reference audio (highly recommended for better quality and to avoid Whisper errors)
    @Published var referenceText: String = ""

    /// Whether voice cloning mode is enabled
    @Published var isCloneMode: Bool = false

    /// Whether reference audio is being transcribed
    @Published var isTranscribing: Bool = false

    /// Fast cloning mode (x_vector_only — faster, slightly less accurate)
    @Published var cloneFastMode: Bool = false

    /// Use lightweight 0.6B model for cloning (faster, lower quality)
    @Published var cloneFastModel: Bool = false

    /// Target accent for voice cloning (nil = automatic from reference audio)
    @Published var cloneTargetAccent: CloneTargetAccent? = nil

    // MARK: - Saved Cloned Voice Profiles

    /// List of saved cloned voice profiles
    @Published var savedClonedVoices: [ClonedVoiceProfileDTO] = []

    /// Currently selected saved profile ID (nil = manual/new)
    @Published var selectedClonedVoiceId: String? = nil

    /// Name for saving a new clone profile
    @Published var cloneProfileName: String = ""

    /// Whether a clone profile save is in progress
    @Published var isSavingCloneProfile: Bool = false

    /// Whether to show the save clone profile sheet
    @Published var showSaveCloneProfileSheet: Bool = false

    // MARK: - Qwen3 VoiceDesign / Accent State

    /// Selected accent preset (VoiceAccent.rawValue, "" = none / CustomVoice mode)
    @Published var selectedAccent: String = ""

    /// Gender for VoiceDesign mode (VoiceGender.rawValue)
    @Published var voiceDesignGender: String = "female"

    /// Custom voice description text (overrides accent preset when non-empty)
    @Published var voiceDesignCustom: String = ""

    // MARK: - Screen Capture State

    /// Indica si está capturando pantalla + OCR
    @Published var isCapturing: Bool = false

    // MARK: - Batch Import State

    /// Indica si está importando imágenes en lote
    @Published var isImportingImages: Bool = false

    /// Progreso de importación (current, total)
    @Published var importProgress: (current: Int, total: Int) = (0, 0)

    /// Resultado de la importación para mostrar en alerta
    @Published var importResult: String?

    /// Indica si se debe mostrar la alerta de resultado de importación
    @Published var showImportResult: Bool = false

    // MARK: - Merge/Export State

    /// Indica si está mergeando/exportando
    @Published var isMerging: Bool = false

    /// Resultado del merge para mostrar en alerta
    @Published var mergeResult: MergeProjectResponse?

    /// Indica si se debe mostrar la alerta de resultado de merge
    @Published var showMergeResult: Bool = false

    // MARK: - Computed Properties

    /// Indica si el proyecto tiene entries
    var hasEntries: Bool { !entries.isEmpty }

    /// Indica si el proyecto tiene audio generado
    var hasAudio: Bool {
        audioPath != nil && !audioPath!.isEmpty
    }

    /// Indica si se puede guardar el proyecto
    /// Ahora solo requiere nombre (el texto es opcional)
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading &&
        !isGenerating
    }

    /// Indica si se puede generar audio
    var canGenerate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedVoiceId != nil &&
        !isLoading &&
        !isGenerating
    }

    /// Indica si se puede reproducir audio
    var canPlay: Bool {
        (hasAudio || playingEntryId != nil) && !isLoading && !isGenerating
    }

    /// Progreso de reproducción (0.0 - 1.0)
    var playbackProgress: Double {
        guard audioDuration > 0 else { return 0 }
        return currentTime / audioDuration
    }

    /// Tiempo actual formateado (m:ss)
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    /// Duración total formateada (m:ss)
    var audioDurationFormatted: String {
        formatTime(audioDuration)
    }

    /// Texto de progreso de importación
    var importProgressText: String {
        "Processing image \(importProgress.current) of \(importProgress.total)..."
    }

    /// Indica si es un proyecto nuevo (no tiene ID)
    var isNewProject: Bool {
        projectId == nil
    }

    /// Título de la vista
    var viewTitle: String {
        isNewProject ? "New Project" : "Edit Project"
    }

    /// Resetea el estado para un nuevo proyecto
    func reset() {
        projectId = nil
        name = ""
        text = ""
        selectedVoiceId = nil
        speed = 1.0
        isLoading = false
        isGenerating = false
        error = nil
        estimatedDuration = "0:00"
        audioPath = nil
        isPlaying = false
        currentTime = 0
        audioDuration = 0
        waveformSamples = []
        entries = []
        playingEntryId = nil
        currentPlayingIndex = -1
        selectedEntryTab = nil
        entryTexts = [:]
        autoSaveState = .idle
    }

    // MARK: - Private Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
