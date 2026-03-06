import Foundation
import AVFoundation

/// Kokoro TTS adapter that runs inference locally using ONNX Runtime
/// Pipeline: text → espeak-ng phonemes → tokenize → ONNX inference → trim → WAV
final class KokoroONNXAdapter: TTSPort {

    // MARK: - Dependencies

    /// Exposed for TTSServerCoordinator to retry model loading
    let engine: KokoroONNXEngineProtocol
    private let phonemizer: EspeakPhonemizerProtocol
    private let tokenizer: KokoroTokenizerProtocol
    private let embeddingStore: VoiceEmbeddingStoreProtocol

    // MARK: - Configuration

    private let trimSilence: Bool
    private let sampleRate: UInt32 = 24000

    // MARK: - Init

    init(
        engine: KokoroONNXEngineProtocol,
        phonemizer: EspeakPhonemizerProtocol,
        tokenizer: KokoroTokenizerProtocol,
        embeddingStore: VoiceEmbeddingStoreProtocol,
        trimSilence: Bool = true
    ) {
        self.engine = engine
        self.phonemizer = phonemizer
        self.tokenizer = tokenizer
        self.embeddingStore = embeddingStore
        self.trimSilence = trimSilence
    }

    // MARK: - TTSPort

    var provider: Voice.TTSProvider { .kokoro }

    var isAvailable: Bool {
        get async {
            engine.isLoaded && phonemizer.isAvailable
        }
    }

    func availableVoices() async -> [Voice] {
        // Same voices as KokoroTTSAdapter - they share the same model
        do {
            let voiceIds = try embeddingStore.availableVoiceIds()
            return voiceIds.map { voiceId in
                Voice(
                    id: voiceId,
                    name: formatVoiceName(voiceId),
                    language: languageForVoice(voiceId),
                    provider: .kokoro,
                    isDefault: voiceId == "ef_dora"
                )
            }
        } catch {
            // Fallback to hardcoded list
            return KokoroONNXAdapter.defaultVoices
        }
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        // Ensure model is loaded
        if !engine.isLoaded {
            try engine.loadModel()
        }

        // 1. Phonemize: text → IPA phonemes
        let language = mapLanguageForEspeak(voice.language)
        let phonemes = try phonemizer.phonemize(text: text.value, language: language)

        guard !phonemes.isEmpty else {
            throw InfrastructureError.ttsRequestFailed("Phonemization produced empty result")
        }

        // 2. Split into batches if too long
        let batches = splitPhonemes(phonemes, maxLength: KokoroTokenizer.maxPhonemeLength)

        // 3. Load voice embedding
        let embedding = try embeddingStore.loadEmbedding(voiceId: voiceConfiguration.voiceId)

        // 4. Process each batch
        var allAudio: [Float32] = []

        for batch in batches {
            // Tokenize
            let tokens = tokenizer.tokenize(batch)
            guard !tokens.isEmpty else { continue }

            // Get style for token count
            let style = embedding.styleForTokenCount(tokens.count)

            // Add padding: [0] + tokens + [0]
            let paddedTokens = KokoroTokenizer.addPadding(tokens)

            // Run inference
            let speed = Float32(voiceConfiguration.speed.value)
            let audioSamples = try engine.infer(
                tokens: paddedTokens,
                style: style,
                speed: speed
            )

            // Trim silence
            var processed = audioSamples
            if trimSilence {
                let trimmed = AudioTrimmer.trim(processed)
                if !trimmed.isEmpty {
                    processed = trimmed
                }
            }

            allAudio.append(contentsOf: processed)
        }

        guard !allAudio.isEmpty else {
            throw InfrastructureError.ttsRequestFailed("No audio generated")
        }

        // 5. Encode to WAV
        let wavData = WAVEncoder.encode(samples: allAudio, sampleRate: sampleRate)
        let duration = WAVEncoder.duration(sampleCount: allAudio.count, sampleRate: sampleRate)

        return try AudioData(data: wavData, duration: duration)
    }

    // MARK: - Phoneme Batching

    /// Split phonemes into batches respecting max length
    /// Prefer splitting at punctuation marks
    private func splitPhonemes(_ phonemes: String, maxLength: Int) -> [String] {
        guard phonemes.count > maxLength else {
            return [phonemes]
        }

        // Split by punctuation and spaces
        var batches: [String] = []
        var currentBatch = ""

        let parts = phonemes.components(separatedBy: CharacterSet(charactersIn: ".,!?;"))

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if currentBatch.count + trimmed.count + 1 >= maxLength {
                if !currentBatch.isEmpty {
                    batches.append(currentBatch.trimmingCharacters(in: .whitespaces))
                }
                currentBatch = trimmed
            } else {
                if !currentBatch.isEmpty {
                    currentBatch += " "
                }
                currentBatch += trimmed
            }
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch.trimmingCharacters(in: .whitespaces))
        }

        return batches.isEmpty ? [phonemes.prefix(maxLength).description] : batches
    }

    // MARK: - Language Mapping

    private func mapLanguageForEspeak(_ language: String) -> String {
        // Map BCP-47 to espeak language codes
        let lowered = language.lowercased()
        let mappings: [String: String] = [
            "es-es": "es",
            "en-us": "en-us",
            "en-gb": "en-gb",
            "fr-fr": "fr-fr",
            "it-it": "it",
            "pt-br": "pt-br",
            "ja-jp": "ja",
            "zh-cn": "cmn",
            "ko-kr": "ko",
            "hi-in": "hi",
        ]
        return mappings[lowered] ?? lowered
    }

    // MARK: - Voice Name Formatting

    private func formatVoiceName(_ voiceId: String) -> String {
        // Voice IDs are like "ef_dora", "am_adam"
        // First char: language prefix, second: gender (f/m)
        // Rest after underscore: name
        guard voiceId.count >= 3 else { return voiceId }

        let parts = voiceId.split(separator: "_", maxSplits: 1)
        guard parts.count == 2 else { return voiceId }

        let name = parts[1].prefix(1).uppercased() + parts[1].dropFirst()
        let langLabel = languageLabelForVoice(voiceId)

        return "\(name) (\(langLabel))"
    }

    private func languageForVoice(_ voiceId: String) -> String {
        guard let firstChar = voiceId.first else { return "en-US" }
        switch firstChar {
        case "a": return "en-US"   // American
        case "b": return "en-GB"   // British
        case "e": return "es-ES"   // Español
        case "f": return "fr-FR"   // Français
        case "i": return "it-IT"   // Italiano
        case "p": return "pt-BR"   // Português
        case "j": return "ja-JP"   // Japanese
        case "z": return "zh-CN"   // Chinese
        case "k": return "ko-KR"   // Korean
        case "h": return "hi-IN"   // Hindi
        default: return "en-US"
        }
    }

    private func languageLabelForVoice(_ voiceId: String) -> String {
        guard let firstChar = voiceId.first else { return "English" }
        switch firstChar {
        case "a": return "American"
        case "b": return "British"
        case "e": return "Español"
        case "f": return "Français"
        case "i": return "Italiano"
        case "p": return "Português"
        case "j": return "日本語"
        case "z": return "中文"
        case "k": return "한국어"
        case "h": return "हिन्दी"
        default: return "English"
        }
    }

    // MARK: - Default Voices (fallback)

    static let defaultVoices: [Voice] = [
        Voice(id: "ef_dora", name: "Dora (Español)", language: "es-ES", provider: .kokoro, isDefault: false),
        Voice(id: "em_santa", name: "Santa (Español)", language: "es-ES", provider: .kokoro, isDefault: false),
        Voice(id: "em_alex", name: "Alex (Español)", language: "es-ES", provider: .kokoro, isDefault: true),
        Voice(id: "af_bella", name: "Bella (American)", language: "en-US", provider: .kokoro, isDefault: false),
        Voice(id: "af_sarah", name: "Sarah (American)", language: "en-US", provider: .kokoro, isDefault: false),
        Voice(id: "am_adam", name: "Adam (American)", language: "en-US", provider: .kokoro, isDefault: false),
        Voice(id: "bf_emma", name: "Emma (British)", language: "en-GB", provider: .kokoro, isDefault: false),
        Voice(id: "bm_george", name: "George (British)", language: "en-GB", provider: .kokoro, isDefault: false),
    ]
}
