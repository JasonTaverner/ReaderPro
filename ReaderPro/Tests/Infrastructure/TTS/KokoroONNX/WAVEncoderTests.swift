import XCTest
@testable import ReaderPro

final class WAVEncoderTests: XCTestCase {

    // MARK: - RIFF Header Tests

    func test_encode_shouldStartWithRIFF() {
        // Arrange
        let samples: [Float32] = [0.0, 0.5, -0.5]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        let riff = String(data: wav[0..<4], encoding: .ascii)
        XCTAssertEqual(riff, "RIFF")
    }

    func test_encode_shouldContainWAVEFormat() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        let wave = String(data: wav[8..<12], encoding: .ascii)
        XCTAssertEqual(wave, "WAVE")
    }

    func test_encode_shouldHaveCorrectFileSize() {
        // Arrange - 100 samples * 2 bytes = 200 bytes data
        let samples = [Float32](repeating: 0.0, count: 100)

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        // Total = 44 header + 200 data = 244 bytes
        XCTAssertEqual(wav.count, 244)

        // ChunkSize field = file size - 8
        let chunkSize = wav.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: 4, as: UInt32.self)
        }
        XCTAssertEqual(chunkSize, UInt32(wav.count - 8))
    }

    // MARK: - fmt Sub-chunk Tests

    func test_encode_shouldHavePCMFormat() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - AudioFormat at offset 20, should be 1 (PCM)
        let audioFormat = wav.withUnsafeBytes { buffer -> UInt16 in
            buffer.load(fromByteOffset: 20, as: UInt16.self)
        }
        XCTAssertEqual(audioFormat, 1)
    }

    func test_encode_shouldHaveMonoChannel() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - NumChannels at offset 22
        let numChannels = wav.withUnsafeBytes { buffer -> UInt16 in
            buffer.load(fromByteOffset: 22, as: UInt16.self)
        }
        XCTAssertEqual(numChannels, 1)
    }

    func test_encode_shouldHave24kHzSampleRate() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - SampleRate at offset 24
        let sampleRate = wav.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: 24, as: UInt32.self)
        }
        XCTAssertEqual(sampleRate, 24000)
    }

    func test_encode_shouldHave16BitDepth() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - BitsPerSample at offset 34
        let bitsPerSample = wav.withUnsafeBytes { buffer -> UInt16 in
            buffer.load(fromByteOffset: 34, as: UInt16.self)
        }
        XCTAssertEqual(bitsPerSample, 16)
    }

    func test_encode_shouldHaveCorrectByteRate() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - ByteRate = SampleRate * NumChannels * BytesPerSample = 24000 * 1 * 2 = 48000
        let byteRate = wav.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: 28, as: UInt32.self)
        }
        XCTAssertEqual(byteRate, 48000)
    }

    // MARK: - Data Sub-chunk Tests

    func test_encode_shouldHaveDataSubchunk() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - "data" at offset 36
        let dataMarker = String(data: wav[36..<40], encoding: .ascii)
        XCTAssertEqual(dataMarker, "data")
    }

    func test_encode_shouldHaveCorrectDataSize() {
        // Arrange - 50 samples * 2 bytes = 100 bytes
        let samples = [Float32](repeating: 0.0, count: 50)

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - Subchunk2Size at offset 40
        let dataSize = wav.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: 40, as: UInt32.self)
        }
        XCTAssertEqual(dataSize, 100)
    }

    // MARK: - Sample Conversion Tests

    func test_encode_silenceShouldBeZero() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - First sample at offset 44 should be 0
        let sample = wav.withUnsafeBytes { buffer -> Int16 in
            buffer.load(fromByteOffset: 44, as: Int16.self)
        }
        XCTAssertEqual(sample, 0)
    }

    func test_encode_maxPositiveSample() {
        // Arrange
        let samples: [Float32] = [1.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        let sample = wav.withUnsafeBytes { buffer -> Int16 in
            buffer.load(fromByteOffset: 44, as: Int16.self)
        }
        XCTAssertEqual(sample, Int16.max)
    }

    func test_encode_maxNegativeSample() {
        // Arrange
        let samples: [Float32] = [-1.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        let sample = wav.withUnsafeBytes { buffer -> Int16 in
            buffer.load(fromByteOffset: 44, as: Int16.self)
        }
        // -1.0 * 32767 = -32767
        XCTAssertEqual(sample, -Int16.max)
    }

    func test_encode_clampsOverflow() {
        // Arrange - values beyond [-1, 1] should be clamped
        let samples: [Float32] = [2.0, -3.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert
        let sample1 = wav.withUnsafeBytes { buffer -> Int16 in
            buffer.load(fromByteOffset: 44, as: Int16.self)
        }
        let sample2 = wav.withUnsafeBytes { buffer -> Int16 in
            buffer.load(fromByteOffset: 46, as: Int16.self)
        }
        XCTAssertEqual(sample1, Int16.max) // clamped to 1.0
        XCTAssertEqual(sample2, -Int16.max) // clamped to -1.0
    }

    // MARK: - Empty Input

    func test_encode_emptySamples_shouldProduceHeaderOnly() {
        // Arrange
        let samples: [Float32] = []

        // Act
        let wav = WAVEncoder.encode(samples: samples)

        // Assert - 44 bytes header, 0 bytes data
        XCTAssertEqual(wav.count, 44)
    }

    // MARK: - Custom Sample Rate

    func test_encode_customSampleRate_shouldBeReflectedInHeader() {
        // Arrange
        let samples: [Float32] = [0.0]

        // Act
        let wav = WAVEncoder.encode(samples: samples, sampleRate: 44100)

        // Assert
        let sampleRate = wav.withUnsafeBytes { buffer -> UInt32 in
            buffer.load(fromByteOffset: 24, as: UInt32.self)
        }
        XCTAssertEqual(sampleRate, 44100)
    }

    // MARK: - Duration

    func test_duration_shouldCalculateCorrectly() {
        // 24000 samples at 24kHz = 1.0 second
        let duration = WAVEncoder.duration(sampleCount: 24000)
        XCTAssertEqual(duration, 1.0, accuracy: 0.001)
    }

    func test_duration_halfSecond_shouldCalculateCorrectly() {
        // 12000 samples at 24kHz = 0.5 second
        let duration = WAVEncoder.duration(sampleCount: 12000)
        XCTAssertEqual(duration, 0.5, accuracy: 0.001)
    }
}
