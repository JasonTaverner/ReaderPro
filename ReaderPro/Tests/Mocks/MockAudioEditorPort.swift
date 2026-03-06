import Foundation
@testable import ReaderPro

final class MockAudioEditorPort: AudioEditorPort {

    // MARK: - Call Tracking

    var trimCallCount = 0
    var mergeCallCount = 0
    var concatenateCallCount = 0
    var adjustSpeedCallCount = 0
    var adjustVolumeCallCount = 0
    var fadeInCallCount = 0
    var fadeOutCallCount = 0
    var getDurationCallCount = 0
    var normalizeCallCount = 0

    // MARK: - Captured Arguments

    var lastConcatenateAudioPaths: [String]?
    var lastConcatenateSilenceDuration: TimeInterval?
    var lastConcatenateOutputPath: String?
    var lastMergeAudioPaths: [String]?

    // MARK: - Stubbed Returns

    var concatenateResult: String = "/exports/audio_completo.wav"
    var mergeResult: String = "/merged/audio.wav"
    var trimResult: String = "/trimmed/audio.wav"
    var getDurationResult: TimeInterval = 10.0

    // MARK: - Error Injection

    var errorToThrow: Error?

    // MARK: - AudioEditorPort Implementation

    func trim(audioPath: String, timeRange: TimeRange) async throws -> String {
        trimCallCount += 1
        if let error = errorToThrow { throw error }
        return trimResult
    }

    func merge(audioPaths: [String]) async throws -> String {
        mergeCallCount += 1
        lastMergeAudioPaths = audioPaths
        if let error = errorToThrow { throw error }
        return mergeResult
    }

    func adjustSpeed(audioPath: String, rate: Double) async throws -> String {
        adjustSpeedCallCount += 1
        if let error = errorToThrow { throw error }
        return audioPath
    }

    func adjustVolume(audioPath: String, factor: Double) async throws -> String {
        adjustVolumeCallCount += 1
        if let error = errorToThrow { throw error }
        return audioPath
    }

    func fadeIn(audioPath: String, duration: TimeInterval) async throws -> String {
        fadeInCallCount += 1
        if let error = errorToThrow { throw error }
        return audioPath
    }

    func fadeOut(audioPath: String, duration: TimeInterval) async throws -> String {
        fadeOutCallCount += 1
        if let error = errorToThrow { throw error }
        return audioPath
    }

    func getDuration(audioPath: String) async throws -> TimeInterval {
        getDurationCallCount += 1
        if let error = errorToThrow { throw error }
        return getDurationResult
    }

    func normalize(audioPath: String) async throws -> String {
        normalizeCallCount += 1
        if let error = errorToThrow { throw error }
        return audioPath
    }

    func concatenate(audioPaths: [String], silenceDuration: TimeInterval, outputPath: String) async throws -> String {
        concatenateCallCount += 1
        lastConcatenateAudioPaths = audioPaths
        lastConcatenateSilenceDuration = silenceDuration
        lastConcatenateOutputPath = outputPath
        if let error = errorToThrow { throw error }
        return concatenateResult
    }
}
