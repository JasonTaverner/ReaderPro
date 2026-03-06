import Foundation

/// DTO para voces de TTS en la UI
struct VoiceDTO: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let language: String
    let provider: String
    let isDefault: Bool

    /// Crea un VoiceDTO desde un Voice del dominio
    init(from voice: Voice) {
        self.id = voice.id
        self.name = voice.name
        self.language = voice.language
        self.provider = voice.provider.rawValue
        self.isDefault = voice.isDefault
    }

    /// Inicializador directo (para testing)
    init(id: String, name: String, language: String, provider: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.language = language
        self.provider = provider
        self.isDefault = isDefault
    }

    /// Display name con idioma
    var displayName: String {
        "\(name) (\(language))"
    }

    /// Convierte el DTO de vuelta a una entidad Voice del dominio
    func toVoice() -> Voice {
        Voice(
            id: id,
            name: name,
            language: language,
            provider: Voice.TTSProvider(rawValue: provider) ?? .native,
            isDefault: isDefault
        )
    }
}

