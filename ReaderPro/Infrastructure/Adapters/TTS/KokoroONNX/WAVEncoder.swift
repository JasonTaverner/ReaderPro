import Foundation

/// Encodes Float32 audio samples into WAV format (PCM 16-bit, mono)
enum WAVEncoder {

    // MARK: - Constants

    /// Kokoro outputs at 24kHz
    static let sampleRate: UInt32 = 24000
    static let numChannels: UInt16 = 1
    static let bitsPerSample: UInt16 = 16
    private static let bytesPerSample: UInt16 = bitsPerSample / 8

    // MARK: - Public API

    /// Encode Float32 samples to WAV Data
    /// - Parameters:
    ///   - samples: Audio samples in [-1.0, 1.0] range
    ///   - sampleRate: Sample rate (default 24000 Hz)
    /// - Returns: Complete WAV file as Data
    static func encode(samples: [Float32], sampleRate: UInt32 = WAVEncoder.sampleRate) -> Data {
        let dataSize = UInt32(samples.count) * UInt32(bytesPerSample)
        let fileSize = 36 + dataSize // 44 byte header - 8 bytes for RIFF chunk header

        var data = Data(capacity: Int(44 + dataSize))

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)                           // ChunkID
        data.append(littleEndian: fileSize)                             // ChunkSize
        data.append(contentsOf: "WAVE".utf8)                           // Format

        // fmt sub-chunk
        data.append(contentsOf: "fmt ".utf8)                           // Subchunk1ID
        data.append(littleEndian: UInt32(16))                          // Subchunk1Size (PCM)
        data.append(littleEndian: UInt16(1))                           // AudioFormat (PCM = 1)
        data.append(littleEndian: numChannels)                         // NumChannels
        data.append(littleEndian: sampleRate)                          // SampleRate
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bytesPerSample)
        data.append(littleEndian: byteRate)                            // ByteRate
        let blockAlign = numChannels * bytesPerSample
        data.append(littleEndian: blockAlign)                          // BlockAlign
        data.append(littleEndian: bitsPerSample)                       // BitsPerSample

        // data sub-chunk
        data.append(contentsOf: "data".utf8)                           // Subchunk2ID
        data.append(littleEndian: dataSize)                            // Subchunk2Size

        // Convert Float32 [-1.0, 1.0] to Int16
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Value = Int16(clamped * Float32(Int16.max))
            data.append(littleEndian: int16Value)
        }

        return data
    }

    /// Calculate audio duration in seconds from sample count
    static func duration(sampleCount: Int, sampleRate: UInt32 = WAVEncoder.sampleRate) -> TimeInterval {
        Double(sampleCount) / Double(sampleRate)
    }
}

// MARK: - Data Extension for Little-Endian Append

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}
