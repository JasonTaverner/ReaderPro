import Foundation
import Accelerate

/// Trims leading and trailing silence from audio samples
/// Port of librosa.effects.trim() used in kokoro-onnx
enum AudioTrimmer {

    // MARK: - Configuration

    /// Default threshold in dB below peak to consider as silence
    static let defaultTopDB: Float = 60.0

    /// Default frame length for RMS calculation
    static let defaultFrameLength: Int = 2048

    /// Default hop length between frames
    static let defaultHopLength: Int = 512

    // MARK: - Public API

    /// Trim silence from beginning and end of audio
    /// - Parameters:
    ///   - samples: Float32 audio samples
    ///   - topDB: Threshold in dB below peak RMS (default 60)
    ///   - frameLength: Analysis frame size (default 2048)
    ///   - hopLength: Hop between frames (default 512)
    /// - Returns: Trimmed audio samples
    static func trim(
        _ samples: [Float32],
        topDB: Float = defaultTopDB,
        frameLength: Int = defaultFrameLength,
        hopLength: Int = defaultHopLength
    ) -> [Float32] {
        guard samples.count >= frameLength else {
            return samples
        }

        // 1. Compute RMS for each frame
        let rmsValues = computeRMS(samples, frameLength: frameLength, hopLength: hopLength)

        guard !rmsValues.isEmpty else {
            return samples
        }

        // 2. Convert RMS to dB relative to peak
        let dbValues = amplitudeToDBRelativeToPeak(rmsValues)

        // 3. Find non-silent frames (above -topDB threshold)
        let nonSilentFrames = dbValues.enumerated().compactMap { index, db -> Int? in
            db > -topDB ? index : nil
        }

        guard let firstNonSilent = nonSilentFrames.first,
              let lastNonSilent = nonSilentFrames.last else {
            // Entire signal is silence
            return []
        }

        // 4. Convert frame indices to sample indices
        let startSample = firstNonSilent * hopLength
        let endSample = min(samples.count, (lastNonSilent + 1) * hopLength)

        return Array(samples[startSample..<endSample])
    }

    // MARK: - Private

    /// Compute RMS energy for each frame
    private static func computeRMS(
        _ samples: [Float32],
        frameLength: Int,
        hopLength: Int
    ) -> [Float32] {
        // Center-pad the signal
        let padAmount = frameLength / 2
        var padded = [Float32](repeating: 0, count: padAmount)
        padded.append(contentsOf: samples)
        padded.append(contentsOf: [Float32](repeating: 0, count: padAmount))

        let numFrames = max(0, (padded.count - frameLength) / hopLength + 1)
        guard numFrames > 0 else { return [] }

        var rmsValues = [Float32](repeating: 0, count: numFrames)

        for i in 0..<numFrames {
            let start = i * hopLength
            let end = min(start + frameLength, padded.count)
            let frameCount = end - start

            guard frameCount > 0 else { continue }

            // Compute mean of squared values using Accelerate
            var sumSquared: Float32 = 0
            padded.withUnsafeBufferPointer { buffer in
                let framePtr = buffer.baseAddress! + start
                vDSP_svesq(framePtr, 1, &sumSquared, vDSP_Length(frameCount))
            }

            let meanSquared = sumSquared / Float32(frameCount)
            rmsValues[i] = sqrtf(meanSquared)
        }

        return rmsValues
    }

    /// Convert amplitude values to dB relative to peak
    /// Equivalent to: 20 * log10(amplitude / max_amplitude)
    private static func amplitudeToDBRelativeToPeak(_ amplitudes: [Float32]) -> [Float32] {
        guard let peak = amplitudes.max(), peak > 0 else {
            return [Float32](repeating: -.infinity, count: amplitudes.count)
        }

        let amin: Float = 1e-5

        return amplitudes.map { amplitude in
            let safeAmplitude = max(amplitude, amin)
            let safePeak = max(peak, amin)
            return 20.0 * log10f(safeAmplitude / safePeak)
        }
    }
}
