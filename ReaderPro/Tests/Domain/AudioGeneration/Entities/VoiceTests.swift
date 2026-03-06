import XCTest
@testable import ReaderPro

/// Tests para la Entity Voice
/// Entity con identidad única, representa una voz disponible para TTS
final class VoiceTests: XCTestCase {

    // MARK: - Creation Tests

    func test_createVoice_withValidData_shouldSucceed() {
        // Arrange & Act
        let voice = Voice(
            id: "af_bella",
            name: "Bella",
            language: "en-US",
            provider: .native,
            isDefault: false
        )

        // Assert
        XCTAssertEqual(voice.id, "af_bella")
        XCTAssertEqual(voice.name, "Bella")
        XCTAssertEqual(voice.language, "en-US")
        XCTAssertEqual(voice.provider, .native)
        XCTAssertFalse(voice.isDefault)
    }

    func test_createVoice_withDefaultTrue_shouldSucceed() {
        // Arrange & Act
        let voice = Voice(
            id: "default",
            name: "Default Voice",
            language: "es-ES",
            provider: .native,
            isDefault: true
        )

        // Assert
        XCTAssertTrue(voice.isDefault)
    }

    // MARK: - TTSProvider Tests

    func test_provider_native_shouldHaveCorrectRawValue() {
        // Act
        let provider = Voice.TTSProvider.native

        // Assert
        XCTAssertEqual(provider.rawValue, "native")
    }

    func test_provider_kokoro_shouldHaveCorrectRawValue() {
        // Act
        let provider = Voice.TTSProvider.kokoro

        // Assert
        XCTAssertEqual(provider.rawValue, "kokoro")
    }

    func test_provider_qwen3_shouldHaveCorrectRawValue() {
        // Act
        let provider = Voice.TTSProvider.qwen3

        // Assert
        XCTAssertEqual(provider.rawValue, "qwen3")
    }

    func test_provider_allCases_shouldContainThreeProviders() {
        // Act
        let allCases = Voice.TTSProvider.allCases

        // Assert
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.native))
        XCTAssertTrue(allCases.contains(.kokoro))
        XCTAssertTrue(allCases.contains(.qwen3))
    }

    func test_provider_displayName_native_shouldReturnCorrectString() {
        // Act
        let displayName = Voice.TTSProvider.native.displayName

        // Assert
        XCTAssertEqual(displayName, "Nativo (macOS)")
    }

    func test_provider_displayName_kokoro_shouldReturnCorrectString() {
        // Act
        let displayName = Voice.TTSProvider.kokoro.displayName

        // Assert
        XCTAssertEqual(displayName, "Kokoro TTS")
    }

    func test_provider_displayName_qwen3_shouldReturnCorrectString() {
        // Act
        let displayName = Voice.TTSProvider.qwen3.displayName

        // Assert
        XCTAssertEqual(displayName, "Qwen3 TTS")
    }

    // MARK: - Identifiable Tests

    func test_voice_shouldBeIdentifiable() {
        // Arrange
        let voice = Voice(
            id: "test_voice",
            name: "Test",
            language: "en-US",
            provider: .native,
            isDefault: false
        )

        // Assert - Voice conforma Identifiable
        XCTAssertEqual(voice.id, "test_voice")
    }

    // MARK: - Equatable Tests

    func test_equality_withSameId_shouldBeEqual() {
        // Arrange
        let voice1 = Voice(id: "voice1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false)
        let voice2 = Voice(id: "voice1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false)

        // Assert - Entities se comparan por ID
        XCTAssertEqual(voice1, voice2)
    }

    func test_equality_withSameIdButDifferentName_shouldBeEqual() {
        // Arrange - Entities se comparan SOLO por ID
        let voice1 = Voice(id: "voice1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false)
        let voice2 = Voice(id: "voice1", name: "Different Name", language: "en-US", provider: .native, isDefault: false)

        // Assert - Mismo ID = igual entity
        XCTAssertEqual(voice1, voice2)
    }

    func test_equality_withDifferentId_shouldNotBeEqual() {
        // Arrange
        let voice1 = Voice(id: "voice1", name: "Voice", language: "en-US", provider: .native, isDefault: false)
        let voice2 = Voice(id: "voice2", name: "Voice", language: "en-US", provider: .native, isDefault: false)

        // Assert - Diferente ID = diferente entity
        XCTAssertNotEqual(voice1, voice2)
    }

    // MARK: - Hashable Tests

    func test_hashable_canBeUsedInSet() {
        // Arrange
        let voice1 = Voice(id: "v1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false)
        let voice2 = Voice(id: "v2", name: "Voice 2", language: "es-ES", provider: .kokoro, isDefault: false)
        let voice3 = Voice(id: "v1", name: "Voice 1 Updated", language: "en-GB", provider: .qwen3, isDefault: true)

        // Act
        var voiceSet: Set<Voice> = []
        voiceSet.insert(voice1)
        voiceSet.insert(voice2)
        voiceSet.insert(voice3)  // Mismo ID que voice1

        // Assert - Set elimina duplicados por ID
        XCTAssertEqual(voiceSet.count, 2)
        XCTAssertTrue(voiceSet.contains(voice1))
        XCTAssertTrue(voiceSet.contains(voice2))
    }

    func test_hashable_canBeUsedInDictionary() {
        // Arrange
        let voice1 = Voice(id: "v1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false)
        let voice2 = Voice(id: "v2", name: "Voice 2", language: "es-ES", provider: .kokoro, isDefault: false)

        // Act
        var dict: [Voice: String] = [:]
        dict[voice1] = "English"
        dict[voice2] = "Spanish"

        // Assert
        XCTAssertEqual(dict[voice1], "English")
        XCTAssertEqual(dict[voice2], "Spanish")
        XCTAssertEqual(dict.count, 2)
    }

    // MARK: - Language Tests

    func test_voice_withDifferentLanguages_shouldStore() {
        // Arrange
        let languages = ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR"]

        // Act & Assert
        for lang in languages {
            let voice = Voice(id: "test", name: "Test", language: lang, provider: .native, isDefault: false)
            XCTAssertEqual(voice.language, lang)
        }
    }

    // MARK: - Default Voice Tests

    func test_filterDefaultVoices_shouldWork() {
        // Arrange
        let voices = [
            Voice(id: "v1", name: "Voice 1", language: "en-US", provider: .native, isDefault: true),
            Voice(id: "v2", name: "Voice 2", language: "es-ES", provider: .kokoro, isDefault: false),
            Voice(id: "v3", name: "Voice 3", language: "fr-FR", provider: .qwen3, isDefault: true),
            Voice(id: "v4", name: "Voice 4", language: "de-DE", provider: .native, isDefault: false)
        ]

        // Act
        let defaultVoices = voices.filter { $0.isDefault }

        // Assert
        XCTAssertEqual(defaultVoices.count, 2)
        XCTAssertTrue(defaultVoices.contains { $0.id == "v1" })
        XCTAssertTrue(defaultVoices.contains { $0.id == "v3" })
    }

    // MARK: - Practical Usage Tests

    func test_voices_canBeStoredInArray() {
        // Arrange
        let voices = [
            Voice(id: "bella", name: "Bella", language: "en-US", provider: .native, isDefault: false),
            Voice(id: "alex", name: "Alex", language: "en-US", provider: .kokoro, isDefault: false),
            Voice(id: "maria", name: "Maria", language: "es-ES", provider: .qwen3, isDefault: true)
        ]

        // Assert
        XCTAssertEqual(voices.count, 3)
        XCTAssertEqual(voices[0].name, "Bella")
        XCTAssertEqual(voices[1].name, "Alex")
        XCTAssertEqual(voices[2].name, "Maria")
    }

    func test_voices_canBeFilteredByProvider() {
        // Arrange
        let voices = [
            Voice(id: "v1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false),
            Voice(id: "v2", name: "Voice 2", language: "es-ES", provider: .kokoro, isDefault: false),
            Voice(id: "v3", name: "Voice 3", language: "fr-FR", provider: .kokoro, isDefault: false),
            Voice(id: "v4", name: "Voice 4", language: "de-DE", provider: .qwen3, isDefault: false)
        ]

        // Act
        let kokoroVoices = voices.filter { $0.provider == .kokoro }

        // Assert
        XCTAssertEqual(kokoroVoices.count, 2)
        XCTAssertTrue(kokoroVoices.allSatisfy { $0.provider == .kokoro })
    }

    func test_voices_canBeFilteredByLanguage() {
        // Arrange
        let voices = [
            Voice(id: "v1", name: "Voice 1", language: "en-US", provider: .native, isDefault: false),
            Voice(id: "v2", name: "Voice 2", language: "es-ES", provider: .kokoro, isDefault: false),
            Voice(id: "v3", name: "Voice 3", language: "en-US", provider: .qwen3, isDefault: false)
        ]

        // Act
        let englishVoices = voices.filter { $0.language == "en-US" }

        // Assert
        XCTAssertEqual(englishVoices.count, 2)
        XCTAssertTrue(englishVoices.contains { $0.id == "v1" })
        XCTAssertTrue(englishVoices.contains { $0.id == "v3" })
    }

    func test_voices_canBeSorted() {
        // Arrange
        let voices = [
            Voice(id: "c", name: "Charlie", language: "en-US", provider: .native, isDefault: false),
            Voice(id: "a", name: "Alice", language: "es-ES", provider: .kokoro, isDefault: false),
            Voice(id: "b", name: "Bob", language: "fr-FR", provider: .qwen3, isDefault: false)
        ]

        // Act
        let sorted = voices.sorted { $0.name < $1.name }

        // Assert
        XCTAssertEqual(sorted[0].name, "Alice")
        XCTAssertEqual(sorted[1].name, "Bob")
        XCTAssertEqual(sorted[2].name, "Charlie")
    }

    // MARK: - Edge Cases

    func test_voice_withEmptyStrings_shouldStore() {
        // Arrange & Act
        let voice = Voice(id: "", name: "", language: "", provider: .native, isDefault: false)

        // Assert - Entity no valida en construcción (a diferencia de Value Objects)
        XCTAssertEqual(voice.id, "")
        XCTAssertEqual(voice.name, "")
        XCTAssertEqual(voice.language, "")
    }

    func test_voice_withSpecialCharacters_shouldStore() {
        // Arrange & Act
        let voice = Voice(
            id: "voice_123-test",
            name: "María José (España)",
            language: "es-ES",
            provider: .native,
            isDefault: false
        )

        // Assert
        XCTAssertEqual(voice.name, "María José (España)")
    }
}
