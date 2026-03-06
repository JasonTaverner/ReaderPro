import Foundation
import AVFoundation

/// Adapter para TTS nativo de macOS usando AVSpeechSynthesizer
/// Funciona sin servidor externo - siempre disponible como fallback
final class NativeTTSAdapter: TTSPort {

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - TTSPort Implementation

    var provider: Voice.TTSProvider {
        .native
    }

    var isAvailable: Bool {
        get async {
            true // Native TTS is always available on macOS
        }
    }

    func availableVoices() async -> [Voice] {
        let systemVoices = AVSpeechSynthesisVoice.speechVoices()

        // Filter for premium and enhanced quality voices, fallback to all if none found
        let qualityVoices = systemVoices.filter { voice in
            voice.quality == .premium || voice.quality == .enhanced
        }

        let voicesToUse = qualityVoices.isEmpty ? systemVoices : qualityVoices

        // Deduplicate by name (keep highest quality)
        var seen = Set<String>()
        var result: [Voice] = []

        for avVoice in voicesToUse.sorted(by: { $0.quality.rawValue > $1.quality.rawValue }) {
            let key = avVoice.name
            if seen.contains(key) { continue }
            seen.insert(key)

            result.append(Voice(
                id: avVoice.identifier,
                name: avVoice.name,
                language: avVoice.language,
                provider: .native,
                isDefault: avVoice.identifier == AVSpeechSynthesisVoice.currentLanguageCode()
            ))
        }

        // Sort: default language first, then alphabetically
        let currentLang = AVSpeechSynthesisVoice.currentLanguageCode()
        result.sort { a, b in
            let aMatch = a.language.hasPrefix(currentLang.prefix(2))
            let bMatch = b.language.hasPrefix(currentLang.prefix(2))
            if aMatch != bMatch { return aMatch }
            return a.name < b.name
        }

        return result
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        // 1. Create utterance
        let utterance = AVSpeechUtterance(string: text.value)

        // 2. Set voice
        if let avVoice = AVSpeechSynthesisVoice(identifier: voice.id) {
            utterance.voice = avVoice
        } else if let avVoice = AVSpeechSynthesisVoice(language: voice.language) {
            utterance.voice = avVoice
        }

        // 3. Map speed: our [0.5, 2.0] → AVFoundation's rate
        // AVSpeechUtteranceDefaultSpeechRate = 0.5, min = 0.0, max = 1.0
        // Map: 0.5x → 0.3, 1.0x → 0.5, 2.0x → 0.7
        let mappedRate = Float(0.3 + (voiceConfiguration.speed.value - 0.5) * (0.4 / 1.5))
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate,
                           min(AVSpeechUtteranceMaximumSpeechRate, mappedRate))

        // 4. Synthesize to audio buffers using write()
        let samples = try await synthesizeToSamples(utterance: utterance)

        guard !samples.isEmpty else {
            throw InfrastructureError.ttsRequestFailed("Native TTS produced no audio")
        }

        // 5. Determine the sample rate from the synthesis (default 22050 for macOS TTS)
        let sampleRate: UInt32 = 22050

        // 6. Encode to WAV using existing WAVEncoder
        let wavData = WAVEncoder.encode(samples: samples, sampleRate: sampleRate)
        let duration = WAVEncoder.duration(sampleCount: samples.count, sampleRate: sampleRate)

        return try AudioData(data: wavData, duration: duration)
    }

    // MARK: - Private

    private func synthesizeToSamples(utterance: AVSpeechUtterance) async throws -> [Float32] {
        try await withCheckedThrowingContinuation { continuation in
            var allSamples: [Float32] = []
            var capturedSampleRate: Double?

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    // nil buffer signals completion
                    if capturedSampleRate == nil && !allSamples.isEmpty {
                        continuation.resume(returning: allSamples)
                    } else if allSamples.isEmpty {
                        // Empty buffer at end = completion
                        continuation.resume(returning: allSamples)
                    }
                    return
                }

                if pcmBuffer.frameLength == 0 {
                    // Empty buffer = synthesis complete
                    continuation.resume(returning: allSamples)
                    return
                }

                capturedSampleRate = pcmBuffer.format.sampleRate

                // Extract Float32 samples from the PCM buffer
                if let floatData = pcmBuffer.floatChannelData {
                    let frameCount = Int(pcmBuffer.frameLength)
                    let channelData = floatData[0]
                    for i in 0..<frameCount {
                        allSamples.append(channelData[i])
                    }
                } else if let int16Data = pcmBuffer.int16ChannelData {
                    // Convert Int16 to Float32
                    let frameCount = Int(pcmBuffer.frameLength)
                    let channelData = int16Data[0]
                    for i in 0..<frameCount {
                        allSamples.append(Float32(channelData[i]) / Float32(Int16.max))
                    }
                }
            }
        }
    }
}
