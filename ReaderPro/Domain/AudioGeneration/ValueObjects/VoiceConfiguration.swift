import Foundation

/// Value Object que representa la configuración de una voz para TTS
/// Contiene voiceId, speed, y opcionalmente instruct/referenceAudioURL para Qwen3
/// Inmutable (struct con let)
struct VoiceConfiguration: Equatable {
    let voiceId: String
    let speed: Speed
    let instruct: String?
    let referenceAudioURL: URL?
    /// Manual transcript of the reference audio for voice cloning.
    /// Providing this avoids the need for automatic transcription (Whisper) on the server.
    let referenceText: String?
    /// Complete voice description for VoiceDesign mode (Qwen3-TTS).
    /// When non-nil, the adapter uses VoiceDesign model instead of CustomVoice.
    let voiceDesignInstruct: String?
    /// Language code for VoiceDesign mode (e.g. "es", "fr", "de").
    /// Ensures the server uses the correct language instead of defaulting to English.
    let voiceDesignLanguage: String?
    /// When true, use x_vector_only_mode for faster voice cloning (less accurate).
    let cloneFastMode: Bool
    /// When true, use the lightweight 0.6B Base model instead of 1.7B for cloning.
    let cloneFastModel: Bool
    /// Accent instruct for voice cloning (e.g. "Speak with a Castilian Spanish accent from Spain").
    /// Passed as `instruct` parameter alongside the cloned voice to steer accent/pronunciation.
    let cloneAccentInstruct: String?
    /// Server-side clone model override ("voxcpm" for maximum quality 48 kHz).
    /// nil keeps the default Qwen3 Base model selection.
    let cloneModel: String?
    /// VoxCPM2: classifier-free guidance (1.0-3.0). Higher = more stable/faithful,
    /// lower = more expressive. nil uses the model default (2.0).
    let voxcpmCfgValue: Double?
    /// VoxCPM2: diffusion inference steps (5-30). Higher = better quality, slower.
    /// nil uses the model default (10).
    let voxcpmSteps: Int?

    init(
        voiceId: String,
        speed: Speed,
        instruct: String? = nil,
        referenceAudioURL: URL? = nil,
        referenceText: String? = nil,
        voiceDesignInstruct: String? = nil,
        voiceDesignLanguage: String? = nil,
        cloneFastMode: Bool = false,
        cloneFastModel: Bool = false,
        cloneAccentInstruct: String? = nil,
        cloneModel: String? = nil,
        voxcpmCfgValue: Double? = nil,
        voxcpmSteps: Int? = nil
    ) {
        self.voiceId = voiceId
        self.speed = speed
        self.instruct = instruct
        self.referenceAudioURL = referenceAudioURL
        self.referenceText = referenceText
        self.voiceDesignInstruct = voiceDesignInstruct
        self.voiceDesignLanguage = voiceDesignLanguage
        self.cloneFastMode = cloneFastMode
        self.cloneFastModel = cloneFastModel
        self.cloneAccentInstruct = cloneAccentInstruct
        self.cloneModel = cloneModel
        self.voxcpmCfgValue = voxcpmCfgValue
        self.voxcpmSteps = voxcpmSteps
    }

    /// Value Object para velocidad de reproducción
    /// Rango válido: 0.5 - 2.0
    struct Speed: Equatable {
        let value: Double

        /// Crea una velocidad validada
        /// - Parameter value: Velocidad entre 0.5 y 2.0
        /// - Throws: DomainError.invalidSpeed si está fuera del rango
        init(_ value: Double) throws {
            guard (0.5...2.0).contains(value) else {
                throw DomainError.invalidSpeed
            }
            self.value = value
        }

        /// Velocidad normal (1.0x)
        static let normal = try! Speed(1.0)
    }
}
