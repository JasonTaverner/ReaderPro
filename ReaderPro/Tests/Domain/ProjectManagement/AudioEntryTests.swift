import XCTest
@testable import ReaderPro

/// Tests para la Entity AudioEntry
/// Representa una entrada individual en un proyecto (texto + audio + metadata)
final class AudioEntryTests: XCTestCase {

    // MARK: - Helper

    private func makeValidText() -> TextContent {
        try! TextContent("Este es un texto de prueba")
    }

    // MARK: - Creation Tests

    func test_createAudioEntry_withTextOnly_shouldSucceed() throws {
        // Arrange
        let text = makeValidText()

        // Act
        let entry = AudioEntry(text: text)

        // Assert
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.text, text)
        XCTAssertNil(entry.audioPath)
        XCTAssertNil(entry.imagePath)
        XCTAssertNotNil(entry.createdAt)
    }

    func test_createAudioEntry_withTextAndAudioPath_shouldSucceed() throws {
        // Arrange
        let text = makeValidText()
        let audioPath = "/path/to/audio.wav"

        // Act
        let entry = AudioEntry(text: text, audioPath: audioPath)

        // Assert
        XCTAssertEqual(entry.audioPath, audioPath)
        XCTAssertNil(entry.imagePath)
    }

    func test_createAudioEntry_withAllPaths_shouldSucceed() throws {
        // Arrange
        let text = makeValidText()
        let audioPath = "/path/to/audio.wav"
        let imagePath = "/path/to/image.png"

        // Act
        let entry = AudioEntry(text: text, audioPath: audioPath, imagePath: imagePath)

        // Assert
        XCTAssertEqual(entry.audioPath, audioPath)
        XCTAssertEqual(entry.imagePath, imagePath)
    }

    func test_createAudioEntry_shouldGenerateUniqueId() throws {
        // Arrange
        let text = makeValidText()

        // Act
        let entry1 = AudioEntry(text: text)
        let entry2 = AudioEntry(text: text)

        // Assert - Cada entry debe tener ID único
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func test_createAudioEntry_shouldSetCreatedAtToNow() throws {
        // Arrange
        let text = makeValidText()
        let before = Date()

        // Act
        let entry = AudioEntry(text: text)
        let after = Date()

        // Assert
        XCTAssertGreaterThanOrEqual(entry.createdAt, before)
        XCTAssertLessThanOrEqual(entry.createdAt, after)
    }

    // MARK: - Reconstitution Tests (from persistence)

    func test_createAudioEntry_withExistingId_shouldUseProvidedId() throws {
        // Arrange - Simular reconstitución desde base de datos
        let text = makeValidText()
        let existingId = EntryId()
        let createdAt = Date(timeIntervalSince1970: 1234567890)

        // Act
        let entry = AudioEntry(
            id: existingId,
            text: text,
            audioPath: "/audio.wav",
            imagePath: "/image.png",
            createdAt: createdAt
        )

        // Assert
        XCTAssertEqual(entry.id, existingId)
        XCTAssertEqual(entry.createdAt, createdAt)
    }

    // MARK: - Mutability Tests

    func test_setAudioPath_shouldUpdatePath() throws {
        // Arrange
        var entry = AudioEntry(text: makeValidText())
        XCTAssertNil(entry.audioPath)

        // Act
        entry.setAudioPath("/new/path/audio.wav")

        // Assert
        XCTAssertEqual(entry.audioPath, "/new/path/audio.wav")
    }

    func test_setImagePath_shouldUpdatePath() throws {
        // Arrange
        var entry = AudioEntry(text: makeValidText())
        XCTAssertNil(entry.imagePath)

        // Act
        entry.setImagePath("/new/path/image.png")

        // Assert
        XCTAssertEqual(entry.imagePath, "/new/path/image.png")
    }

    func test_setAudioPath_multiple_times_shouldKeepLatest() throws {
        // Arrange
        var entry = AudioEntry(text: makeValidText())

        // Act
        entry.setAudioPath("/path1.wav")
        entry.setAudioPath("/path2.wav")
        entry.setAudioPath("/path3.wav")

        // Assert
        XCTAssertEqual(entry.audioPath, "/path3.wav")
    }

    // MARK: - Has Audio/Image Tests

    func test_hasAudio_withNoAudioPath_shouldReturnFalse() throws {
        // Arrange
        let entry = AudioEntry(text: makeValidText())

        // Assert
        XCTAssertFalse(entry.hasAudio)
    }

    func test_hasAudio_withAudioPath_shouldReturnTrue() throws {
        // Arrange
        let entry = AudioEntry(text: makeValidText(), audioPath: "/audio.wav")

        // Assert
        XCTAssertTrue(entry.hasAudio)
    }

    func test_hasImage_withNoImagePath_shouldReturnFalse() throws {
        // Arrange
        let entry = AudioEntry(text: makeValidText())

        // Assert
        XCTAssertFalse(entry.hasImage)
    }

    func test_hasImage_withImagePath_shouldReturnTrue() throws {
        // Arrange
        let entry = AudioEntry(text: makeValidText(), imagePath: "/image.png")

        // Assert
        XCTAssertTrue(entry.hasImage)
    }

    // MARK: - Equatable Tests (por ID)

    func test_equality_withSameId_shouldBeEqual() throws {
        // Arrange
        let id = EntryId()
        let text1 = try TextContent("Texto 1")
        let text2 = try TextContent("Texto 2")

        let entry1 = AudioEntry(id: id, text: text1, audioPath: nil, imagePath: nil, createdAt: Date())
        let entry2 = AudioEntry(id: id, text: text2, audioPath: "/different.wav", imagePath: nil, createdAt: Date())

        // Assert - Mismo ID = misma entity (aunque otros campos sean diferentes)
        XCTAssertEqual(entry1, entry2)
    }

    func test_equality_withDifferentId_shouldNotBeEqual() throws {
        // Arrange
        let text = makeValidText()
        let entry1 = AudioEntry(text: text)
        let entry2 = AudioEntry(text: text)

        // Assert - Diferente ID = diferente entity
        XCTAssertNotEqual(entry1, entry2)
    }

    // MARK: - Hashable Tests

    func test_hashable_canBeUsedInSet() throws {
        // Arrange
        let entry1 = AudioEntry(text: makeValidText())
        let entry2 = AudioEntry(text: makeValidText())
        let entry3 = AudioEntry(id: entry1.id, text: makeValidText(), audioPath: nil, imagePath: nil, createdAt: Date())

        // Act
        var entrySet: Set<AudioEntry> = []
        entrySet.insert(entry1)
        entrySet.insert(entry2)
        entrySet.insert(entry3)  // Mismo ID que entry1

        // Assert
        XCTAssertEqual(entrySet.count, 2)
    }

    func test_hashable_canBeUsedInDictionary() throws {
        // Arrange
        let entry1 = AudioEntry(text: makeValidText())
        let entry2 = AudioEntry(text: makeValidText())

        // Act
        var dict: [AudioEntry: String] = [:]
        dict[entry1] = "Entry 1"
        dict[entry2] = "Entry 2"

        // Assert
        XCTAssertEqual(dict[entry1], "Entry 1")
        XCTAssertEqual(dict[entry2], "Entry 2")
    }

    // MARK: - Practical Usage Tests

    func test_entries_canBeStoredInArray() throws {
        // Arrange
        let entries = [
            AudioEntry(text: try TextContent("Texto 1"), audioPath: "/audio1.wav"),
            AudioEntry(text: try TextContent("Texto 2"), audioPath: "/audio2.wav"),
            AudioEntry(text: try TextContent("Texto 3"))
        ]

        // Assert
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries[0].hasAudio)
        XCTAssertTrue(entries[1].hasAudio)
        XCTAssertFalse(entries[2].hasAudio)
    }

    func test_entries_canBeFilteredByHasAudio() throws {
        // Arrange
        let entries = [
            AudioEntry(text: try TextContent("Con audio"), audioPath: "/audio.wav"),
            AudioEntry(text: try TextContent("Sin audio")),
            AudioEntry(text: try TextContent("Con audio 2"), audioPath: "/audio2.wav")
        ]

        // Act
        let withAudio = entries.filter { $0.hasAudio }

        // Assert
        XCTAssertEqual(withAudio.count, 2)
    }

    func test_entries_canBeSortedByCreatedAt() throws {
        // Arrange
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let entries = [
            AudioEntry(id: EntryId(), text: makeValidText(), audioPath: nil, imagePath: nil, createdAt: date2),
            AudioEntry(id: EntryId(), text: makeValidText(), audioPath: nil, imagePath: nil, createdAt: date1),
            AudioEntry(id: EntryId(), text: makeValidText(), audioPath: nil, imagePath: nil, createdAt: date3)
        ]

        // Act
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // Assert
        XCTAssertEqual(sorted[0].createdAt, date1)
        XCTAssertEqual(sorted[1].createdAt, date2)
        XCTAssertEqual(sorted[2].createdAt, date3)
    }

    // MARK: - Edge Cases

    func test_createAudioEntry_withVeryLongText_shouldSucceed() throws {
        // Arrange - 6000 caracteres (límite de TextContent)
        let longString = String(repeating: "a", count: 6000)
        let text = try TextContent(longString)

        // Act
        let entry = AudioEntry(text: text)

        // Assert
        XCTAssertEqual(entry.text.value.count, 6000)
    }

    func test_setAudioPath_withEmptyString_shouldStore() throws {
        // Arrange
        var entry = AudioEntry(text: makeValidText())

        // Act
        entry.setAudioPath("")

        // Assert
        XCTAssertEqual(entry.audioPath, "")
        // Note: hasAudio verifica si es nil, no si está vacío
        XCTAssertTrue(entry.hasAudio)  // audioPath existe aunque esté vacío
    }

    func test_audioEntry_withUnicodeInPaths_shouldStore() throws {
        // Arrange
        var entry = AudioEntry(text: makeValidText())

        // Act
        entry.setAudioPath("/path/ñoño/audio-español.wav")
        entry.setImagePath("/path/世界/imagen.png")

        // Assert
        XCTAssertEqual(entry.audioPath, "/path/ñoño/audio-español.wav")
        XCTAssertEqual(entry.imagePath, "/path/世界/imagen.png")
    }
}
