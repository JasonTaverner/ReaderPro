import Foundation

/// ViewModel para SettingsView
/// Solo contiene estado de UI - sin lógica de negocio
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Path del directorio actual de almacenamiento
    @Published var currentDirectoryPath: String = ""

    /// Indica si se está usando un directorio personalizado
    @Published var isCustomDirectory: Bool = false

    /// Indica si se debe mostrar la alerta de restart requerido
    @Published var showRestartAlert: Bool = false

    /// Mensaje de error, nil si no hay error
    @Published var error: String? = nil

    // MARK: - Cloned Voices

    /// Path to the cloned voices directory
    @Published var clonedVoicesDirectoryPath: String = ""

    /// Number of saved cloned voice profiles
    @Published var clonedVoicesCount: Int = 0

    // MARK: - Default TTS Provider

    /// Default TTS provider persisted via UserDefaults ("native", "kokoro" or "qwen3")
    @Published var defaultProvider: String = "kokoro"

    /// Kokoro server URL
    @Published var kokoroServerURL: String = "http://127.0.0.1:8880"

    /// Qwen3 server URL
    @Published var qwen3ServerURL: String = "http://127.0.0.1:8890"

    /// Default Kokoro mode persisted via UserDefaults ("localONNX" or "remoteServer")
    @Published var defaultKokoroMode: String = "localONNX"

    /// Default Qwen3 accent (VoiceAccent rawValue or "" for none)
    @Published var defaultQwen3Accent: String = ""

    /// Default Qwen3 emotion (SpeechEmotion rawValue)
    @Published var defaultQwen3Emotion: String = "neutral"

    /// Default Qwen3 gender (VoiceGender rawValue)
    @Published var defaultQwen3Gender: String = "female"

    // MARK: - Default Clone Settings

    /// Default fast cloning mode (x_vector_only, faster but less accurate)
    @Published var defaultCloneFastMode: Bool = false

    /// Default lightweight model (0.6B instead of 1.7B)
    @Published var defaultCloneFastModel: Bool = false

    /// Default clone target accent (CloneTargetAccent rawValue or "" for automatic)
    @Published var defaultCloneAccent: String = ""

    /// Default clone mode enabled
    @Published var defaultCloneEnabled: Bool = false

    /// Default saved cloned voice profile ID ("" for none/manual)
    @Published var defaultCloneProfileId: String = ""

    // MARK: - Atajos globales

    /// Comando "leer el portapapeles" activado
    @Published var clipboardReadEnabled: Bool = true
    /// Combinación de teclas del comando (rawValue de GlobalHotKeyCombo)
    @Published var clipboardReadHotKey: String = "ctrl_opt_r"
    /// Proveedor TTS que usa este comando
    @Published var clipboardReadProvider: String = "supertonic"

    /// Comando "crear entrada desde el portapapeles" activado
    @Published var clipboardEntryEnabled: Bool = true
    /// Combinación de teclas del comando
    @Published var clipboardEntryHotKey: String = "ctrl_opt_l"
    /// Proveedor TTS para generar el audio de la entrada
    @Published var clipboardEntryProvider: String = "supertonic"
    /// Proyecto destino: "inbox" | "last"
    @Published var clipboardEntryTarget: String = "inbox"
    /// Generar el audio automáticamente al crear la entrada
    @Published var clipboardEntryGenerateAudio: Bool = true

    /// Dictado → portapapeles activado
    @Published var dictationClipboardEnabled: Bool = true
    @Published var dictationClipboardHotKey: String = "ctrl_opt_t"
    /// Dictado → entrada activado
    @Published var dictationEntryEnabled: Bool = true
    @Published var dictationEntryHotKey: String = "ctrl_opt_e"
    /// Idioma del dictado (whisper)
    @Published var dictationLanguage: String = "es"

    /// Available cloned voice profiles for the picker
    @Published var clonedVoiceProfiles: [ClonedVoiceProfileDTO] = []

    // MARK: - TTS Model Status

    /// Name of the currently loaded TTS model (nil = none loaded)
    @Published var loadedModelName: String? = nil

    /// Whether the server is reachable
    @Published var isServerOnline: Bool = false

    /// Whether a model operation (load/unload) is in progress
    @Published var isModelOperationInProgress: Bool = false

    // MARK: - Server Toggle State

    /// Whether the Kokoro server is currently enabled/running
    @Published var isKokoroServerEnabled: Bool = false

    /// Whether the Qwen3 server is currently enabled/running
    @Published var isQwen3ServerEnabled: Bool = false

    /// Status of the Kokoro server
    @Published var kokoroServerStatus: String = "Unknown"

    /// Status of the Qwen3 server
    @Published var qwen3ServerStatus: String = "Unknown"

    /// Whether a server toggle operation is in progress
    @Published var isServerToggleInProgress: Bool = false
}
