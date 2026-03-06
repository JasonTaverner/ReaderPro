import XCTest
@testable import ReaderPro

/// Tests para el Value Object AudioData
/// Representa los datos de audio generados por TTS
final class AudioDataTests: XCTestCase {

    // MARK: - Creation Tests

    func test_createAudioData_withValidData_shouldSucceed() throws {
        // Arrange
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let duration = 10.5

        // Act
        let audioData = try AudioData(data: data, duration: duration)

        // Assert
        XCTAssertEqual(audioData.data, data)
        XCTAssertEqual(audioData.duration, duration)
    }

    func test_createAudioData_withEmptyData_shouldThrow() {
        // Arrange
        let emptyData = Data()

        // Act & Assert
        XCTAssertThrowsError(try AudioData(data: emptyData, duration: 10.0)) { error in
            guard case DomainError.emptyAudioData = error else {
                XCTFail("Expected DomainError.emptyAudioData but got \(error)")
                return
            }
        }
    }

    func test_createAudioData_withZeroDuration_shouldThrow() {
        // Arrange
        let data = Data([0x01, 0x02])

        // Act & Assert
        XCTAssertThrowsError(try AudioData(data: data, duration: 0.0)) { error in
            guard case DomainError.invalidAudioDuration = error else {
                XCTFail("Expected DomainError.invalidAudioDuration but got \(error)")
                return
            }
        }
    }

    func test_createAudioData_withNegativeDuration_shouldThrow() {
        // Arrange
        let data = Data([0x01, 0x02])

        // Act & Assert
        XCTAssertThrowsError(try AudioData(data: data, duration: -1.0)) { error in
            guard case DomainError.invalidAudioDuration = error else {
                XCTFail("Expected DomainError.invalidAudioDuration but got \(error)")
                return
            }
        }
    }

    // MARK: - Size Tests

    func test_sizeInBytes_shouldReturnDataCount() throws {
        // Arrange
        let data = Data(count: 1024)  // 1 KB
        let audioData = try AudioData(data: data, duration: 5.0)

        // Act
        let size = audioData.sizeInBytes

        // Assert
        XCTAssertEqual(size, 1024)
    }

    func test_sizeInKB_shouldCalculateCorrectly() throws {
        // Arrange
        let data = Data(count: 2048)  // 2 KB
        let audioData = try AudioData(data: data, duration: 5.0)

        // Act
        let sizeKB = audioData.sizeInKB

        // Assert
        XCTAssertEqual(sizeKB, 2.0)
    }

    func test_sizeInMB_shouldCalculateCorrectly() throws {
        // Arrange
        let data = Data(count: 1_048_576)  // 1 MB
        let audioData = try AudioData(data: data, duration: 60.0)

        // Act
        let sizeMB = audioData.sizeInMB

        // Assert
        XCTAssertEqual(sizeMB, 1.0, accuracy: 0.01)
    }

    func test_sizeInMB_withSmallData_shouldReturnFraction() throws {
        // Arrange
        let data = Data(count: 524_288)  // 0.5 MB
        let audioData = try AudioData(data: data, duration: 30.0)

        // Act
        let sizeMB = audioData.sizeInMB

        // Assert
        XCTAssertEqual(sizeMB, 0.5, accuracy: 0.01)
    }

    // MARK: - Equatable Tests

    func test_equality_withSameDataAndDuration_shouldBeEqual() throws {
        // Arrange
        let data = Data([0x01, 0x02, 0x03])
        let audio1 = try AudioData(data: data, duration: 5.0)
        let audio2 = try AudioData(data: data, duration: 5.0)

        // Assert
        XCTAssertEqual(audio1, audio2)
    }

    func test_equality_withDifferentData_shouldNotBeEqual() throws {
        // Arrange
        let data1 = Data([0x01, 0x02])
        let data2 = Data([0x03, 0x04])
        let audio1 = try AudioData(data: data1, duration: 5.0)
        let audio2 = try AudioData(data: data2, duration: 5.0)

        // Assert
        XCTAssertNotEqual(audio1, audio2)
    }

    func test_equality_withDifferentDuration_shouldNotBeEqual() throws {
        // Arrange
        let data = Data([0x01, 0x02])
        let audio1 = try AudioData(data: data, duration: 5.0)
        let audio2 = try AudioData(data: data, duration: 10.0)

        // Assert
        XCTAssertNotEqual(audio1, audio2)
    }

    // MARK: - Duration Tests

    func test_createAudioData_withVerySmallDuration_shouldSucceed() throws {
        // Arrange
        let data = Data([0x01])

        // Act
        let audioData = try AudioData(data: data, duration: 0.001)

        // Assert
        XCTAssertEqual(audioData.duration, 0.001)
    }

    func test_createAudioData_withLargeDuration_shouldSucceed() throws {
        // Arrange
        let data = Data(count: 1000)

        // Act
        let audioData = try AudioData(data: data, duration: 3600.0)  // 1 hora

        // Assert
        XCTAssertEqual(audioData.duration, 3600.0)
    }

    // MARK: - Edge Cases

    func test_createAudioData_withSingleByte_shouldSucceed() throws {
        // Arrange
        let data = Data([0xFF])

        // Act
        let audioData = try AudioData(data: data, duration: 0.1)

        // Assert
        XCTAssertEqual(audioData.sizeInBytes, 1)
    }

    func test_createAudioData_withLargeData_shouldSucceed() throws {
        // Arrange - 10 MB de datos
        let data = Data(count: 10_485_760)

        // Act
        let audioData = try AudioData(data: data, duration: 600.0)

        // Assert
        XCTAssertEqual(audioData.sizeInMB, 10.0, accuracy: 0.01)
    }

    func test_createAudioData_withDecimalDuration_shouldSucceed() throws {
        // Arrange
        let data = Data([0x01, 0x02])

        // Act
        let audioData = try AudioData(data: data, duration: 1.234567)

        // Assert
        XCTAssertEqual(audioData.duration, 1.234567, accuracy: 0.000001)
    }

    // MARK: - Practical Usage Tests

    func test_audioData_canBeStoredInArray() throws {
        // Arrange
        let audio1 = try AudioData(data: Data([0x01]), duration: 1.0)
        let audio2 = try AudioData(data: Data([0x02]), duration: 2.0)
        let audio3 = try AudioData(data: Data([0x03]), duration: 3.0)

        // Act
        let audioArray = [audio1, audio2, audio3]

        // Assert
        XCTAssertEqual(audioArray.count, 3)
        XCTAssertEqual(audioArray[0].duration, 1.0)
        XCTAssertEqual(audioArray[1].duration, 2.0)
        XCTAssertEqual(audioArray[2].duration, 3.0)
    }

    func test_audioData_totalSize_calculation() throws {
        // Arrange
        let audio1 = try AudioData(data: Data(count: 1024), duration: 1.0)
        let audio2 = try AudioData(data: Data(count: 2048), duration: 2.0)
        let audio3 = try AudioData(data: Data(count: 512), duration: 0.5)

        // Act
        let totalSize = audio1.sizeInBytes + audio2.sizeInBytes + audio3.sizeInBytes

        // Assert
        XCTAssertEqual(totalSize, 3584)  // 1024 + 2048 + 512
    }

    func test_audioData_totalDuration_calculation() throws {
        // Arrange
        let audios = [
            try AudioData(data: Data([0x01]), duration: 1.5),
            try AudioData(data: Data([0x02]), duration: 2.3),
            try AudioData(data: Data([0x03]), duration: 3.7)
        ]

        // Act
        let totalDuration = audios.reduce(0.0) { $0 + $1.duration }

        // Assert
        XCTAssertEqual(totalDuration, 7.5, accuracy: 0.1)
    }
}
