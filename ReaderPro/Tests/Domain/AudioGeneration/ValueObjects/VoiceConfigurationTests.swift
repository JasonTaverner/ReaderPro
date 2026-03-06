import XCTest
@testable import ReaderPro

/// Tests para VoiceConfiguration y sus Value Objects internos (Speed)
final class VoiceConfigurationTests: XCTestCase {

    // MARK: - Speed Tests

    func test_createSpeed_withValidValue_shouldSucceed() throws {
        // Arrange & Act
        let speed = try VoiceConfiguration.Speed(1.0)

        // Assert
        XCTAssertEqual(speed.value, 1.0)
    }

    func test_createSpeed_withMinimumValue_shouldSucceed() throws {
        // Arrange & Act
        let speed = try VoiceConfiguration.Speed(0.5)

        // Assert
        XCTAssertEqual(speed.value, 0.5)
    }

    func test_createSpeed_withMaximumValue_shouldSucceed() throws {
        // Arrange & Act
        let speed = try VoiceConfiguration.Speed(2.0)

        // Assert
        XCTAssertEqual(speed.value, 2.0)
    }

    func test_createSpeed_belowMinimum_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try VoiceConfiguration.Speed(0.4)) { error in
            guard case DomainError.invalidSpeed = error else {
                XCTFail("Expected DomainError.invalidSpeed but got \(error)")
                return
            }
        }
    }

    func test_createSpeed_aboveMaximum_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try VoiceConfiguration.Speed(2.1)) { error in
            guard case DomainError.invalidSpeed = error else {
                XCTFail("Expected DomainError.invalidSpeed but got \(error)")
                return
            }
        }
    }

    func test_speedNormal_shouldBe1Point0() {
        // Act
        let speed = VoiceConfiguration.Speed.normal

        // Assert
        XCTAssertEqual(speed.value, 1.0)
    }

    // MARK: - VoiceConfiguration Tests

    func test_createVoiceConfiguration_withValidValues_shouldSucceed() throws {
        // Arrange
        let speed = try VoiceConfiguration.Speed(1.2)

        // Act
        let config = VoiceConfiguration(
            voiceId: "af_bella",
            speed: speed
        )

        // Assert
        XCTAssertEqual(config.voiceId, "af_bella")
        XCTAssertEqual(config.speed.value, 1.2)
    }

    func test_createVoiceConfiguration_withDefaults_shouldUseNormalValues() {
        // Arrange & Act
        let config = VoiceConfiguration(
            voiceId: "default",
            speed: .normal
        )

        // Assert
        XCTAssertEqual(config.speed.value, 1.0)
    }

    // MARK: - Equatable Tests

    func test_speedEquality_withSameValue_shouldBeEqual() throws {
        // Arrange
        let speed1 = try VoiceConfiguration.Speed(1.5)
        let speed2 = try VoiceConfiguration.Speed(1.5)

        // Assert
        XCTAssertEqual(speed1, speed2)
    }

    func test_speedEquality_withDifferentValue_shouldNotBeEqual() throws {
        // Arrange
        let speed1 = try VoiceConfiguration.Speed(1.5)
        let speed2 = try VoiceConfiguration.Speed(1.8)

        // Assert
        XCTAssertNotEqual(speed1, speed2)
    }

    func test_voiceConfigurationEquality_withSameValues_shouldBeEqual() throws {
        // Arrange
        let config1 = VoiceConfiguration(
            voiceId: "voice1",
            speed: try VoiceConfiguration.Speed(1.0)
        )
        let config2 = VoiceConfiguration(
            voiceId: "voice1",
            speed: try VoiceConfiguration.Speed(1.0)
        )

        // Assert
        XCTAssertEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withDifferentVoiceId_shouldNotBeEqual() throws {
        // Arrange
        let config1 = VoiceConfiguration(
            voiceId: "voice1",
            speed: .normal
        )
        let config2 = VoiceConfiguration(
            voiceId: "voice2",
            speed: .normal
        )

        // Assert
        XCTAssertNotEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withDifferentSpeed_shouldNotBeEqual() throws {
        // Arrange
        let config1 = VoiceConfiguration(
            voiceId: "voice1",
            speed: try VoiceConfiguration.Speed(1.0)
        )
        let config2 = VoiceConfiguration(
            voiceId: "voice1",
            speed: try VoiceConfiguration.Speed(1.5)
        )

        // Assert
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Instruct & ReferenceAudioURL

    func test_createVoiceConfiguration_withoutInstruct_shouldDefaultToNil() {
        let config = VoiceConfiguration(voiceId: "v1", speed: .normal)
        XCTAssertNil(config.instruct)
    }

    func test_createVoiceConfiguration_withInstruct_shouldStoreValue() {
        let config = VoiceConfiguration(
            voiceId: "v1",
            speed: .normal,
            instruct: "Speak happily"
        )
        XCTAssertEqual(config.instruct, "Speak happily")
    }

    func test_createVoiceConfiguration_withoutReferenceAudioURL_shouldDefaultToNil() {
        let config = VoiceConfiguration(voiceId: "v1", speed: .normal)
        XCTAssertNil(config.referenceAudioURL)
    }

    func test_createVoiceConfiguration_withReferenceAudioURL_shouldStoreValue() {
        let url = URL(fileURLWithPath: "/tmp/reference.wav")
        let config = VoiceConfiguration(
            voiceId: "v1",
            speed: .normal,
            referenceAudioURL: url
        )
        XCTAssertEqual(config.referenceAudioURL, url)
    }

    func test_voiceConfigurationEquality_withDifferentInstruct_shouldNotBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            instruct: "Speak happily"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            instruct: "Speak sadly"
        )
        XCTAssertNotEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withSameInstruct_shouldBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            instruct: "Speak happily"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            instruct: "Speak happily"
        )
        XCTAssertEqual(config1, config2)
    }

    // MARK: - VoiceDesignInstruct

    func test_createVoiceConfiguration_withoutVoiceDesignInstruct_shouldDefaultToNil() {
        let config = VoiceConfiguration(voiceId: "v1", speed: .normal)
        XCTAssertNil(config.voiceDesignInstruct)
    }

    func test_createVoiceConfiguration_withVoiceDesignInstruct_shouldStoreValue() {
        let config = VoiceConfiguration(
            voiceId: "v1",
            speed: .normal,
            voiceDesignInstruct: "A warm female voice with native Spanish accent"
        )
        XCTAssertEqual(config.voiceDesignInstruct, "A warm female voice with native Spanish accent")
    }

    func test_voiceConfigurationEquality_withDifferentVoiceDesignInstruct_shouldNotBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "French accent"
        )
        XCTAssertNotEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withSameVoiceDesignInstruct_shouldBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent"
        )
        XCTAssertEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withNilVsNonNilVoiceDesignInstruct_shouldNotBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent"
        )
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - VoiceDesignLanguage

    func test_createVoiceConfiguration_withoutVoiceDesignLanguage_shouldDefaultToNil() {
        let config = VoiceConfiguration(voiceId: "v1", speed: .normal)
        XCTAssertNil(config.voiceDesignLanguage)
    }

    func test_createVoiceConfiguration_withVoiceDesignLanguage_shouldStoreValue() {
        let config = VoiceConfiguration(
            voiceId: "v1",
            speed: .normal,
            voiceDesignInstruct: "A warm female voice",
            voiceDesignLanguage: "es"
        )
        XCTAssertEqual(config.voiceDesignLanguage, "es")
    }

    func test_voiceConfigurationEquality_withDifferentVoiceDesignLanguage_shouldNotBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent",
            voiceDesignLanguage: "es"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent",
            voiceDesignLanguage: "fr"
        )
        XCTAssertNotEqual(config1, config2)
    }

    func test_voiceConfigurationEquality_withSameVoiceDesignLanguage_shouldBeEqual() {
        let config1 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent",
            voiceDesignLanguage: "es"
        )
        let config2 = VoiceConfiguration(
            voiceId: "v1", speed: .normal,
            voiceDesignInstruct: "Spanish accent",
            voiceDesignLanguage: "es"
        )
        XCTAssertEqual(config1, config2)
    }

    // MARK: - Edge Cases

    func test_createSpeed_withPreciseDecimal_shouldSucceed() throws {
        // Arrange & Act
        let speed = try VoiceConfiguration.Speed(0.85)

        // Assert
        XCTAssertEqual(speed.value, 0.85)
    }

    func test_createSpeed_atBoundaryValues_shouldSucceed() throws {
        // Act & Assert
        XCTAssertNoThrow(try VoiceConfiguration.Speed(0.5))
        XCTAssertNoThrow(try VoiceConfiguration.Speed(2.0))
    }
}
