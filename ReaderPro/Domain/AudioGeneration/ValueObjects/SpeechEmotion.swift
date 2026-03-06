import Foundation

/// Emociones predefinidas para TTS con instrucción de estilo.
/// Value Object puro del dominio — se mapea a instruct text para Qwen3-TTS.
/// Los adapters que no soportan emociones simplemente ignoran el instruct.
enum SpeechEmotion: String, CaseIterable, Equatable {
    case neutral
    case happy
    case sad
    case angry
    case whisper
    case excited
    case calm
    case fearful

    /// Nombre legible para la UI
    var displayName: String {
        switch self {
        case .neutral:  return "Neutral"
        case .happy:    return "Happy"
        case .sad:      return "Sad"
        case .angry:    return "Angry"
        case .whisper:  return "Whisper"
        case .excited:  return "Excited"
        case .calm:     return "Calm"
        case .fearful:  return "Fearful"
        }
    }

    /// Instrucción de estilo para el modelo TTS.
    /// `nil` para neutral (sin instrucción especial).
    var instruct: String? {
        switch self {
        case .neutral:
            return nil
        case .happy:
            return "Speak with a happy and cheerful tone"
        case .sad:
            return "Speak with a sad and melancholic tone"
        case .angry:
            return "Speak with an angry and intense tone"
        case .whisper:
            return "Speak in a soft whisper"
        case .excited:
            return "Speak with excitement and high energy"
        case .calm:
            return "Speak in a calm and soothing tone"
        case .fearful:
            return "Speak with a fearful and trembling voice"
        }
    }
}
