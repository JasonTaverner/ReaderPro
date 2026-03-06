import Foundation

/// Formato de archivo de audio
enum AudioFormat: String, Equatable, CaseIterable {
    case wav    // WAV sin comprimir
    case mp3    // MP3 comprimido
    case m4a    // M4A/AAC
    case flac   // FLAC lossless
    case aiff   // AIFF sin comprimir

    /// Extensión del archivo para este formato
    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        case .flac: return "flac"
        case .aiff: return "aiff"
        }
    }

    /// Nombre legible del formato
    var displayName: String {
        switch self {
        case .wav: return "WAV"
        case .mp3: return "MP3"
        case .m4a: return "M4A (AAC)"
        case .flac: return "FLAC"
        case .aiff: return "AIFF"
        }
    }

    /// Indica si es un formato comprimido
    var isCompressed: Bool {
        switch self {
        case .wav, .aiff: return false
        case .mp3, .m4a, .flac: return true
        }
    }

    /// Indica si es un formato con pérdida
    var isLossy: Bool {
        switch self {
        case .mp3, .m4a: return true
        case .wav, .flac, .aiff: return false
        }
    }
}
