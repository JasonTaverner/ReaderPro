import XCTest
@testable import ReaderPro

final class AudioTrimmerTests: XCTestCase {

    // MARK: - Trim Silence

    func test_trim_leadingSilence_shouldRemoveIt() {
        // Arrange - 4800 samples silence + 2400 samples tone
        let silence = [Float32](repeating: 0.0, count: 4800)
        let tone = makeSineWave(frequency: 440, sampleCount: 2400)
        let samples = silence + tone

        // Act
        let trimmed = AudioTrimmer.trim(samples)

        // Assert - trimmed should be significantly shorter than original
        XCTAssertLessThan(trimmed.count, samples.count)
        // Most of the leading silence should be removed
        // (some samples near frame boundary may remain)
        XCTAssertLessThan(trimmed.count, tone.count + 1024,
                          "Trimmed should remove most of the leading silence")
    }

    func test_trim_trailingSilence_shouldRemoveIt() {
        // Arrange - 2400 samples tone + 4800 samples silence
        let tone = makeSineWave(frequency: 440, sampleCount: 2400)
        let silence = [Float32](repeating: 0.0, count: 4800)
        let samples = tone + silence

        // Act
        let trimmed = AudioTrimmer.trim(samples)

        // Assert
        XCTAssertLessThan(trimmed.count, samples.count)
    }

    func test_trim_bothSides_shouldRemoveBoth() {
        // Arrange
        let silence = [Float32](repeating: 0.0, count: 4800)
        let tone = makeSineWave(frequency: 440, sampleCount: 4800)
        let samples = silence + tone + silence

        // Act
        let trimmed = AudioTrimmer.trim(samples)

        // Assert
        XCTAssertLessThan(trimmed.count, samples.count)
    }

    // MARK: - Edge Cases

    func test_trim_allSilence_shouldReturnEmpty() {
        // Arrange
        let silence = [Float32](repeating: 0.0, count: 4800)

        // Act
        let trimmed = AudioTrimmer.trim(silence)

        // Assert
        XCTAssertTrue(trimmed.isEmpty)
    }

    func test_trim_noSilence_shouldReturnSameLength() {
        // Arrange - continuous tone
        let tone = makeSineWave(frequency: 440, sampleCount: 4800, amplitude: 0.8)

        // Act
        let trimmed = AudioTrimmer.trim(tone)

        // Assert - should be approximately the same length
        // (may differ slightly due to framing)
        let ratio = Float(trimmed.count) / Float(tone.count)
        XCTAssertGreaterThan(ratio, 0.9)
    }

    func test_trim_tooShortForFrame_shouldReturnOriginal() {
        // Arrange - shorter than frame length (2048)
        let samples = [Float32](repeating: 0.5, count: 100)

        // Act
        let trimmed = AudioTrimmer.trim(samples)

        // Assert
        XCTAssertEqual(trimmed.count, samples.count)
    }

    func test_trim_emptySamples_shouldReturnEmpty() {
        // Act
        let trimmed = AudioTrimmer.trim([])

        // Assert
        XCTAssertTrue(trimmed.isEmpty)
    }

    // MARK: - Custom Parameters

    func test_trim_lowerTopDB_shouldTrimMore() {
        // Arrange - quiet signal with silence
        let silence = [Float32](repeating: 0.0, count: 4800)
        let quietTone = makeSineWave(frequency: 440, sampleCount: 4800, amplitude: 0.01)
        let loudTone = makeSineWave(frequency: 440, sampleCount: 4800, amplitude: 0.8)
        let samples = silence + quietTone + loudTone + silence

        // Act
        let trimmed20 = AudioTrimmer.trim(samples, topDB: 20)
        let trimmed80 = AudioTrimmer.trim(samples, topDB: 80)

        // Assert - lower topDB (stricter) should keep less
        XCTAssertLessThanOrEqual(trimmed20.count, trimmed80.count)
    }

    // MARK: - Helpers

    /// Generate a sine wave
    private func makeSineWave(
        frequency: Float,
        sampleCount: Int,
        sampleRate: Float = 24000,
        amplitude: Float = 0.5
    ) -> [Float32] {
        (0..<sampleCount).map { i in
            amplitude * sinf(2.0 * .pi * frequency * Float(i) / sampleRate)
        }
    }

    /// Compute RMS of a signal
    private func rms(_ samples: [Float32]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumSquared = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrtf(sumSquared / Float(samples.count))
    }
}
