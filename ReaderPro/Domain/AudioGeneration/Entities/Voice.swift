import Foundation

/// Entity que representa una voz disponible para Text-to-Speech
/// - Tiene identidad única (id)
/// - Se compara por ID, no por valor
/// - Immutable struct (Entity inmutable en Swift)
struct Voice: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let language: String
    let provider: TTSProvider
    let isDefault: Bool

    /// Proveedor de TTS
    enum TTSProvider: String, Equatable, CaseIterable {
        case native     // AVSpeechSynthesizer (macOS nativo)
        case kokoro     // Kokoro TTS (local)
        case qwen3      // Qwen3-TTS (local o API)

        /// Nombre legible para UI
        var displayName: String {
            switch self {
            case .native:
                return "Nativo (macOS)"
            case .kokoro:
                return "Kokoro TTS"
            case .qwen3:
                return "Qwen3 TTS"
            }
        }
    }

    // MARK: - Equatable (por ID, no por valor)

    static func == (lhs: Voice, rhs: Voice) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable (por ID)

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
