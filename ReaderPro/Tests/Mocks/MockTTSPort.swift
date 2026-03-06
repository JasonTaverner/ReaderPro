import Foundation
@testable import ReaderPro

/// Mock del TTSPort para tests
/// Simula servicios de Text-to-Speech
final class MockTTSPort: TTSPort {

    // MARK: - Call Tracking

    var isAvailableCalled = false
    var availableVoicesCalled = false
    var synthesizeCalled = false
    var synthesizeCallCount = 0

    var lastSynthesizedText: TextContent?
    var lastVoiceConfiguration: VoiceConfiguration?
    var lastVoice: Voice?

    // MARK: - Stub Responses

    var isAvailableValue: Bool = true
    var voicesToReturn: [Voice] = []
    var audioDataToReturn: AudioData?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - TTSPort Implementation

    var isAvailable: Bool {
        get async {
            isAvailableCalled = true
            return isAvailableValue
        }
    }

    func availableVoices() async -> [Voice] {
        availableVoicesCalled = true
        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return voicesToReturn
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        synthesizeCalled = true
        synthesizeCallCount += 1
        lastSynthesizedText = text
        lastVoiceConfiguration = voiceConfiguration
        lastVoice = voice

        if let error = errorToThrow {
            throw error
        }

        guard let audioData = audioDataToReturn else {
            // Return default audio data if not configured
            let defaultData = Data(repeating: 0, count: 1024)
            return try! AudioData(data: defaultData, duration: 10.0)
        }

        return audioData
    }

    var provider: Voice.TTSProvider {
        .native
    }

    // MARK: - Helper Methods

    func reset() {
        isAvailableCalled = false
        availableVoicesCalled = false
        synthesizeCalled = false
        synthesizeCallCount = 0
        lastSynthesizedText = nil
        lastVoiceConfiguration = nil
        lastVoice = nil
        isAvailableValue = true
        voicesToReturn = []
        audioDataToReturn = nil
        errorToThrow = nil
    }
}
