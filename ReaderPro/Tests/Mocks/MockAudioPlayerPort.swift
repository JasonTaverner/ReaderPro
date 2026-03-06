import Foundation
@testable import ReaderPro

/// Mock de AudioPlayerPort para testing
@MainActor
final class MockAudioPlayerPort: AudioPlayerPort {
    var loadCalled = false
    var playCalled = false
    var pauseCalled = false
    var stopCalled = false
    var seekCalled = false
    var setRateCalled = false

    var lastLoadPath: String?
    var lastSeekTime: TimeInterval?
    var lastRate: Float?

    var isPlayingToReturn: Bool = false
    var currentTimeToReturn: TimeInterval = 0
    var durationToReturn: TimeInterval = 0
    var rateToReturn: Float = 1.0
    var samplesToReturn: [Float] = []

    var errorToThrow: Error?
    var delayResponse = false

    /// Callback que se invoca cuando el audio termina de reproducirse
    var onPlaybackComplete: (() -> Void)?

    /// Simula la finalización de reproducción (para testing)
    func simulatePlaybackComplete() {
        onPlaybackComplete?()
    }

    func load(path: String) async throws {
        loadCalled = true
        lastLoadPath = path

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }
    }

    func play() async {
        playCalled = true
    }

    func pause() async {
        pauseCalled = true
    }

    func stop() async {
        stopCalled = true
    }

    func seek(to time: TimeInterval) async {
        seekCalled = true
        lastSeekTime = time
        currentTimeToReturn = time
    }

    func setRate(_ rate: Float) async {
        setRateCalled = true
        lastRate = rate
        rateToReturn = rate
    }

    var isPlaying: Bool {
        isPlayingToReturn
    }

    var currentTime: TimeInterval {
        currentTimeToReturn
    }

    var duration: TimeInterval {
        durationToReturn
    }

    var rate: Float {
        rateToReturn
    }

    func generateWaveformSamples(sampleCount: Int) async throws -> [Float] {
        if let error = errorToThrow {
            throw error
        }
        return samplesToReturn
    }
}
