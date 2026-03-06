import Foundation

/// Gender for VoiceDesign voice description
enum VoiceGender: String, CaseIterable, Equatable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

/// Presets de acento para idiomas sin voz nativa en Qwen3-TTS VoiceDesign mode
/// Cuando el idioma del texto no tiene una CustomVoice nativa (ej: español, francés),
/// se usa VoiceDesign con un instruct que describe la voz completa.
enum VoiceAccent: String, CaseIterable, Equatable {
    // Español
    case spanishSpain
    case spanishMexico
    case spanishArgentina
    // Francés
    case french
    // Alemán
    case german
    // Italiano
    case italian
    // Portugués
    case portugueseBrazil
    case portuguesePortugal
    // Ruso
    case russian

    var displayName: String {
        switch self {
        case .spanishSpain: return "Espa\u{00f1}ol (Espa\u{00f1}a)"
        case .spanishMexico: return "Espa\u{00f1}ol (M\u{00e9}xico)"
        case .spanishArgentina: return "Espa\u{00f1}ol (Argentina)"
        case .french: return "Fran\u{00e7}ais"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Portugu\u{00ea}s (Brasil)"
        case .portuguesePortugal: return "Portugu\u{00ea}s (Portugal)"
        case .russian: return "\u{0420}\u{0443}\u{0441}\u{0441}\u{043a}\u{0438}\u{0439}"
        }
    }

    /// Flag emoji for UI display
    var flag: String {
        switch self {
        case .spanishSpain: return "\u{1f1ea}\u{1f1f8}"
        case .spanishMexico: return "\u{1f1f2}\u{1f1fd}"
        case .spanishArgentina: return "\u{1f1e6}\u{1f1f7}"
        case .french: return "\u{1f1eb}\u{1f1f7}"
        case .german: return "\u{1f1e9}\u{1f1ea}"
        case .italian: return "\u{1f1ee}\u{1f1f9}"
        case .portugueseBrazil: return "\u{1f1e7}\u{1f1f7}"
        case .portuguesePortugal: return "\u{1f1f5}\u{1f1f9}"
        case .russian: return "\u{1f1f7}\u{1f1fa}"
        }
    }

    /// Language code for the accent (used to set the server's lang_code correctly)
    var languageCode: String {
        switch self {
        case .spanishSpain, .spanishMexico, .spanishArgentina: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portugueseBrazil, .portuguesePortugal: return "pt"
        case .russian: return "ru"
        }
    }

    /// Generates the voice description instruct for VoiceDesign mode.
    /// The result is a natural English sentence describing the desired voice.
    /// - Parameters:
    ///   - gender: Male or female voice
    ///   - emotion: Optional emotion/style instruct (e.g. "Speak with a happy tone").
    ///             Appended as speaking style at the end.
    /// - Returns: Complete voice description string for VoiceDesign instruct
    func voiceDesignInstruct(gender: VoiceGender, style emotion: String?) -> String {
        let voiceDesc: String
        let accentDesc = accentDescription

        // Use rich descriptors so the model clearly differentiates gender
        switch gender {
        case .female:
            voiceDesc = "Describe a woman around 30 years old with a warm, clear female voice. She speaks with a native \(accentDesc) accent."
        case .male:
            voiceDesc = "Describe a man around 35 years old with a deep, resonant male voice. He speaks with a native \(accentDesc) accent."
        }

        // Append emotion/style if provided, otherwise default
        if let emotion = emotion, !emotion.isEmpty {
            let suffix = emotion.lowercased().hasPrefix("speak")
                ? " \(emotion.capitalized)."
                : " Speaking \(emotion.lowercased())."
            return voiceDesc + suffix
        } else {
            return voiceDesc + " The voice sounds natural and pleasant."
        }
    }

    /// Returns a CloneTargetAccent matching this VoiceAccent (for use in cloning mode)
    var cloneTargetAccent: CloneTargetAccent? {
        switch self {
        case .spanishSpain: return .spain
        case .spanishMexico: return .mexico
        case .spanishArgentina: return .argentina
        case .french: return .french
        case .german: return .german
        case .italian: return .italian
        case .portugueseBrazil: return .portugueseBrazil
        case .portuguesePortugal: return .portuguesePortugal
        case .russian: return .russian
        }
    }

    /// Accent description in English for the instruct
    private var accentDescription: String {
        switch self {
        case .spanishSpain: return "Castilian Spanish"
        case .spanishMexico: return "Mexican Spanish"
        case .spanishArgentina: return "Argentinian Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portugueseBrazil: return "Brazilian Portuguese"
        case .portuguesePortugal: return "European Portuguese"
        case .russian: return "Russian"
        }
    }
}

/// Target accent for voice cloning mode.
/// Unlike VoiceDesign (which uses a separate model), clone accent instructs are
/// passed alongside the cloned voice to steer pronunciation without switching models.
enum CloneTargetAccent: String, CaseIterable, Identifiable, Equatable {
    case spain
    case mexico
    case argentina
    case french
    case german
    case italian
    case portugueseBrazil
    case portuguesePortugal
    case russian
    case neutral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spain: return "Espa\u{00f1}a (Castellano)"
        case .mexico: return "M\u{00e9}xico"
        case .argentina: return "Argentina"
        case .french: return "Fran\u{00e7}ais"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Portugu\u{00ea}s (Brasil)"
        case .portuguesePortugal: return "Portugu\u{00ea}s (Portugal)"
        case .russian: return "\u{0420}\u{0443}\u{0441}\u{0441}\u{043a}\u{0438}\u{0439}"
        case .neutral: return "Neutral"
        }
    }

    var flag: String {
        switch self {
        case .spain: return "\u{1f1ea}\u{1f1f8}"
        case .mexico: return "\u{1f1f2}\u{1f1fd}"
        case .argentina: return "\u{1f1e6}\u{1f1f7}"
        case .french: return "\u{1f1eb}\u{1f1f7}"
        case .german: return "\u{1f1e9}\u{1f1ea}"
        case .italian: return "\u{1f1ee}\u{1f1f9}"
        case .portugueseBrazil: return "\u{1f1e7}\u{1f1f7}"
        case .portuguesePortugal: return "\u{1f1f5}\u{1f1f9}"
        case .russian: return "\u{1f1f7}\u{1f1fa}"
        case .neutral: return "\u{1f30d}"
        }
    }

    /// Language code passed to the server for correct language routing
    var languageCode: String {
        switch self {
        case .spain, .mexico, .argentina: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portugueseBrazil, .portuguesePortugal: return "pt"
        case .russian: return "ru"
        case .neutral: return "auto"
        }
    }

    /// Instruct string sent to the server to steer accent/pronunciation in cloning mode
    var instruct: String {
        switch self {
        case .spain:
            return "Speak with a clear Castilian Spanish accent from Spain. Use the characteristic Spanish 'z' and 'c' pronunciation. Pronounce words as a native speaker from Madrid would."
        case .mexico:
            return "Speak with a Mexican Spanish accent. Pronounce words as a native speaker from Mexico City would."
        case .argentina:
            return "Speak with an Argentine Spanish accent. Use the characteristic 'sh' sound for 'll' and 'y'."
        case .french:
            return "Speak with a native French accent from Paris. Use standard French pronunciation."
        case .german:
            return "Speak with a native German accent. Use standard Hochdeutsch pronunciation."
        case .italian:
            return "Speak with a native Italian accent. Use standard Italian pronunciation."
        case .portugueseBrazil:
            return "Speak with a Brazilian Portuguese accent. Use Brazilian pronunciation patterns."
        case .portuguesePortugal:
            return "Speak with a European Portuguese accent from Lisbon."
        case .russian:
            return "Speak with a native Russian accent. Use standard Russian pronunciation."
        case .neutral:
            return "Speak in a clear, neutral tone without strong regional accent."
        }
    }
}
