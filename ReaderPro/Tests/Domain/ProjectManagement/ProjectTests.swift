import XCTest
@testable import ReaderPro

/// Tests para el Aggregate Root Project
/// Representa un proyecto completo con entradas de audio y comportamiento del dominio
final class ProjectTests: XCTestCase {

    // MARK: - Type Alias

    typealias ProjectId = Identifier<Project>

    // MARK: - Helpers

    private func makeValidText() -> TextContent {
        try! TextContent("Este es un texto de prueba para el proyecto")
    }

    private func makeValidProjectName() -> ProjectName {
        try! ProjectName("Proyecto de Prueba")
    }

    private func makeValidVoiceConfiguration() -> VoiceConfiguration {
        VoiceConfiguration(
            voiceId: "default-voice",
            speed: .normal
        )
    }

    private func makeValidVoice() -> Voice {
        Voice(
            id: "voice-1",
            name: "Voice Default",
            language: "es-ES",
            provider: .native,
            isDefault: true
        )
    }

    // MARK: - Creation Tests

    func test_createProject_withValidData_shouldSucceed() throws {
        // Arrange
        let name = makeValidProjectName()
        let text = makeValidText()
        let voiceConfig = makeValidVoiceConfiguration()
        let voice = makeValidVoice()

        // Act
        let project = Project(
            name: name,
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice
        )

        // Assert
        XCTAssertNotNil(project.id)
        XCTAssertEqual(project.name, name)
        XCTAssertEqual(project.text, text)
        XCTAssertEqual(project.voiceConfiguration, voiceConfig)
        XCTAssertEqual(project.voice, voice)
        XCTAssertEqual(project.status, .draft)
        XCTAssertNil(project.audioPath)
        XCTAssertTrue(project.entries.isEmpty)
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
        XCTAssertEqual(project.createdAt, project.updatedAt)
    }

    func test_createProject_shouldGenerateUniqueId() throws {
        // Arrange
        let name = makeValidProjectName()
        let text = makeValidText()
        let voiceConfig = makeValidVoiceConfiguration()
        let voice = makeValidVoice()

        // Act
        let project1 = Project(name: name, text: text, voiceConfiguration: voiceConfig, voice: voice)
        let project2 = Project(name: name, text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertNotEqual(project1.id, project2.id)
    }

    func test_createProject_shouldEmitProjectCreatedEvent() throws {
        // Arrange
        let name = makeValidProjectName()
        let text = makeValidText()
        let voiceConfig = makeValidVoiceConfiguration()
        let voice = makeValidVoice()

        // Act
        let project = Project(name: name, text: text, voiceConfiguration: voiceConfig, voice: voice)

        // Assert
        XCTAssertEqual(project.domainEvents.count, 1)
        XCTAssertTrue(project.domainEvents.first is ProjectCreatedEvent)
    }

    // MARK: - Reconstitution Tests

    func test_createProject_withExistingId_shouldUseProvidedId() throws {
        // Arrange - Simular reconstitución desde base de datos
        let id = ProjectId()
        let name = makeValidProjectName()
        let text = makeValidText()
        let voiceConfig = makeValidVoiceConfiguration()
        let voice = makeValidVoice()
        let createdAt = Date(timeIntervalSince1970: 1234567890)
        let updatedAt = Date(timeIntervalSince1970: 1234567900)

        // Act
        let project = Project(
            id: id,
            name: name,
            text: text,
            voiceConfiguration: voiceConfig,
            voice: voice,
            audioPath: "/audio/test.wav",
            status: .ready,
            entries: [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        // Assert
        XCTAssertEqual(project.id, id)
        XCTAssertEqual(project.createdAt, createdAt)
        XCTAssertEqual(project.updatedAt, updatedAt)
        XCTAssertEqual(project.status, .ready)
        XCTAssertEqual(project.audioPath, "/audio/test.wav")
        XCTAssertTrue(project.domainEvents.isEmpty) // No events on reconstitution
    }

    // MARK: - Update TextContent Tests

    func test_updateText_shouldUpdateTextAndInvalidateAudio() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")
        XCTAssertNotNil(project.audioPath)
        XCTAssertEqual(project.status, .ready)
        project.clearEvents()

        // Act
        let newText = try TextContent("Nuevo texto actualizado")
        try project.updateText(newText)

        // Assert
        XCTAssertEqual(project.text, newText)
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
        XCTAssertTrue(project.domainEvents.contains { $0 is ProjectTextUpdatedEvent })
    }

    func test_updateText_shouldUpdateTimestamp() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let originalUpdatedAt = project.updatedAt

        // Wait a bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        // Act
        let newText = try TextContent("Nuevo texto")
        try project.updateText(newText)

        // Assert
        XCTAssertGreaterThan(project.updatedAt, originalUpdatedAt)
    }

    // MARK: - Rename Tests

    func test_rename_shouldUpdateName() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.clearEvents()

        // Act
        let newName = try ProjectName("Proyecto Renombrado")
        try project.rename(newName)

        // Assert
        XCTAssertEqual(project.name, newName)
        XCTAssertTrue(project.domainEvents.contains { $0 is ProjectRenamedEvent })
    }

    func test_rename_shouldNotInvalidateAudio() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")

        // Act
        try project.rename(try ProjectName("Nuevo Nombre"))

        // Assert - El audio debe permanecer
        XCTAssertEqual(project.audioPath, "/audio/test.wav")
        XCTAssertEqual(project.status, .ready)
    }

    // MARK: - Audio Generation Tests

    func test_markAudioGenerated_shouldUpdatePathAndStatus() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
        project.clearEvents()

        // Act
        project.markAudioGenerated(path: "/audio/generated.wav")

        // Assert
        XCTAssertEqual(project.audioPath, "/audio/generated.wav")
        XCTAssertEqual(project.status, .ready)
        XCTAssertTrue(project.domainEvents.contains { $0 is AudioGeneratedEvent })
    }

    func test_markGenerating_shouldUpdateStatus() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertEqual(project.status, .draft)

        // Act
        project.markGenerating()

        // Assert
        XCTAssertEqual(project.status, .generating)
    }

    func test_markError_shouldUpdateStatus() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act
        project.markError()

        // Assert
        XCTAssertEqual(project.status, .error)
    }

    // MARK: - Voice Configuration Tests

    func test_updateVoiceConfiguration_shouldUpdate() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.clearEvents()

        // Act
        let newConfig = VoiceConfiguration(
            voiceId: "new-voice",
            speed: try! VoiceConfiguration.Speed(1.5)
        )
        try project.updateVoiceConfiguration(newConfig)

        // Assert
        XCTAssertEqual(project.voiceConfiguration, newConfig)
    }

    func test_updateVoiceConfiguration_shouldInvalidateAudio() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")
        XCTAssertNotNil(project.audioPath)

        // Act
        let newConfig = VoiceConfiguration(
            voiceId: "different-voice",
            speed: .normal
        )
        try project.updateVoiceConfiguration(newConfig)

        // Assert
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
    }

    func test_updateVoice_shouldUpdate() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act
        let newVoice = Voice(
            id: "voice-2",
            name: "Different Voice",
            language: "en-US",
            provider: .kokoro,
            isDefault: false
        )
        project.updateVoice(newVoice)

        // Assert
        XCTAssertEqual(project.voice, newVoice)
    }

    func test_updateVoice_shouldInvalidateAudio() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")

        // Act
        let newVoice = Voice(
            id: "voice-2",
            name: "Different Voice",
            language: "en-US",
            provider: .qwen3,
            isDefault: false
        )
        project.updateVoice(newVoice)

        // Assert
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
    }

    // MARK: - Entry Management Tests

    func test_addEntry_shouldAddToEntries() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertTrue(project.entries.isEmpty)
        project.clearEvents()

        // Act
        let entry = AudioEntry(text: try TextContent("Entrada 1"))
        try project.addEntry(entry)

        // Assert
        XCTAssertEqual(project.entries.count, 1)
        XCTAssertTrue(project.entries.contains(entry))
        XCTAssertTrue(project.domainEvents.contains { $0 is EntryAddedEvent })
    }

    func test_addEntry_multipleTimes_shouldAddAll() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act
        let entry1 = AudioEntry(text: try TextContent("Entrada 1"))
        let entry2 = AudioEntry(text: try TextContent("Entrada 2"))
        let entry3 = AudioEntry(text: try TextContent("Entrada 3"))

        try project.addEntry(entry1)
        try project.addEntry(entry2)
        try project.addEntry(entry3)

        // Assert
        XCTAssertEqual(project.entries.count, 3)
        XCTAssertTrue(project.entries.contains(entry1))
        XCTAssertTrue(project.entries.contains(entry2))
        XCTAssertTrue(project.entries.contains(entry3))
    }

    func test_removeEntry_shouldRemoveFromEntries() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let entry = AudioEntry(text: try TextContent("Entrada"))
        try project.addEntry(entry)
        XCTAssertEqual(project.entries.count, 1)
        project.clearEvents()

        // Act
        try project.removeEntry(id: entry.id)

        // Assert
        XCTAssertTrue(project.entries.isEmpty)
        XCTAssertTrue(project.domainEvents.contains { $0 is EntryRemovedEvent })
    }

    func test_removeEntry_withNonexistentId_shouldThrow() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act & Assert
        XCTAssertThrowsError(try project.removeEntry(id: EntryId())) { error in
            guard case DomainError.entryNotFound = error else {
                XCTFail("Expected entryNotFound error")
                return
            }
        }
    }

    func test_updateEntry_shouldUpdateExistingEntry() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        var entry = AudioEntry(text: try TextContent("Original"))
        try project.addEntry(entry)

        // Modify entry
        entry.setAudioPath("/audio/updated.wav")
        project.clearEvents()

        // Act
        try project.updateEntry(entry)

        // Assert
        let updatedEntry = project.entries.first { $0.id == entry.id }
        XCTAssertNotNil(updatedEntry)
        XCTAssertEqual(updatedEntry?.audioPath, "/audio/updated.wav")
        XCTAssertTrue(project.domainEvents.contains { $0 is EntryUpdatedEvent })
    }

    func test_updateEntry_withNonexistentId_shouldThrow() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let entry = AudioEntry(text: try TextContent("Entry"))

        // Act & Assert
        XCTAssertThrowsError(try project.updateEntry(entry)) { error in
            guard case DomainError.entryNotFound = error else {
                XCTFail("Expected entryNotFound error")
                return
            }
        }
    }

    // MARK: - Query Tests

    func test_hasAudio_withNoAudioPath_shouldReturnFalse() throws {
        // Arrange
        let project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Assert
        XCTAssertFalse(project.hasAudio)
    }

    func test_hasAudio_withAudioPath_shouldReturnTrue() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")

        // Assert
        XCTAssertTrue(project.hasAudio)
    }

    func test_canRegenerate_whenNotGenerating_shouldReturnTrue() throws {
        // Arrange
        let project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Assert
        XCTAssertTrue(project.canRegenerate)
    }

    func test_canRegenerate_whenGenerating_shouldReturnFalse() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markGenerating()

        // Assert
        XCTAssertFalse(project.canRegenerate)
    }

    // MARK: - Domain Events Tests

    func test_clearEvents_shouldRemoveAllEvents() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertFalse(project.domainEvents.isEmpty)

        // Act
        project.clearEvents()

        // Assert
        XCTAssertTrue(project.domainEvents.isEmpty)
    }

    // MARK: - Practical Usage Tests

    func test_project_fullLifecycle() throws {
        // Arrange - Create project
        var project = Project(
            name: try ProjectName("Mi Proyecto"),
            text: try TextContent("Texto inicial"),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertEqual(project.status, .draft)

        // Act & Assert - Mark generating
        project.markGenerating()
        XCTAssertEqual(project.status, .generating)
        XCTAssertFalse(project.canRegenerate)

        // Act & Assert - Generate audio
        project.markAudioGenerated(path: "/audio/test.wav")
        XCTAssertEqual(project.status, .ready)
        XCTAssertTrue(project.hasAudio)
        XCTAssertTrue(project.canRegenerate)

        // Act & Assert - Update text (invalidates audio)
        try project.updateText(try TextContent("Texto actualizado"))
        XCTAssertEqual(project.status, .draft)
        XCTAssertFalse(project.hasAudio)
        XCTAssertNil(project.audioPath)
    }

    func test_project_withMultipleEntries() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act - Add multiple entries
        try project.addEntry(AudioEntry(text: try TextContent("Entrada 1")))
        try project.addEntry(AudioEntry(text: try TextContent("Entrada 2")))
        try project.addEntry(AudioEntry(text: try TextContent("Entrada 3")))

        // Assert
        XCTAssertEqual(project.entries.count, 3)

        // Act - Remove middle entry
        let middleEntry = project.entries[1]
        try project.removeEntry(id: middleEntry.id)

        // Assert
        XCTAssertEqual(project.entries.count, 2)
        XCTAssertFalse(project.entries.contains(middleEntry))
    }

    // MARK: - Edge Cases

    func test_updateText_withSameText_shouldStillInvalidateAudio() throws {
        // Arrange
        let text = makeValidText()
        var project = Project(
            name: makeValidProjectName(),
            text: text,
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.markAudioGenerated(path: "/audio/test.wav")

        // Act
        try project.updateText(text)

        // Assert - Even if text is the same, audio is invalidated
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
    }

    // MARK: - Cover Image Tests

    func test_thumbnailImagePath_withNoCoverAndNoEntryImages_shouldReturnNil() throws {
        // Arrange
        let project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Assert
        XCTAssertNil(project.thumbnailImagePath)
    }

    func test_thumbnailImagePath_withEntryImage_shouldReturnEntryPath() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let entry = AudioEntry(text: try TextContent("Text"), imagePath: "project/001.png")
        try project.addEntry(entry)

        // Assert
        XCTAssertEqual(project.thumbnailImagePath, "project/001.png")
    }

    func test_thumbnailImagePath_withCoverImage_shouldPreferCover() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let entry = AudioEntry(text: try TextContent("Text"), imagePath: "project/001.png")
        try project.addEntry(entry)
        project.setCoverImage(path: "project/cover.png")

        // Assert
        XCTAssertEqual(project.thumbnailImagePath, "project/cover.png")
    }

    func test_setCoverImage_shouldUpdatePath() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        XCTAssertNil(project.coverImagePath)

        // Act
        project.setCoverImage(path: "project/cover.png")

        // Assert
        XCTAssertEqual(project.coverImagePath, "project/cover.png")
    }

    func test_removeCoverImage_shouldClearPath() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        project.setCoverImage(path: "project/cover.png")
        XCTAssertNotNil(project.coverImagePath)

        // Act
        project.removeCoverImage()

        // Assert
        XCTAssertNil(project.coverImagePath)
    }

    func test_thumbnailImagePath_afterRemoveCover_shouldFallbackToEntry() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )
        let entry = AudioEntry(text: try TextContent("Text"), imagePath: "project/001.png")
        try project.addEntry(entry)
        project.setCoverImage(path: "project/cover.png")
        XCTAssertEqual(project.thumbnailImagePath, "project/cover.png")

        // Act
        project.removeCoverImage()

        // Assert
        XCTAssertEqual(project.thumbnailImagePath, "project/001.png")
    }

    func test_markAudioGenerated_multipleTimes_shouldUpdatePath() throws {
        // Arrange
        var project = Project(
            name: makeValidProjectName(),
            text: makeValidText(),
            voiceConfiguration: makeValidVoiceConfiguration(),
            voice: makeValidVoice()
        )

        // Act
        project.markAudioGenerated(path: "/audio/first.wav")
        project.markAudioGenerated(path: "/audio/second.wav")
        project.markAudioGenerated(path: "/audio/third.wav")

        // Assert
        XCTAssertEqual(project.audioPath, "/audio/third.wav")
    }
}
