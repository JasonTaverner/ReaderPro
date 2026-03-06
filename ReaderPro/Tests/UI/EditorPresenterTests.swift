import XCTest
@testable import ReaderPro

/// Tests para EditorPresenter usando TDD
@MainActor
final class EditorPresenterTests: XCTestCase {

    // MARK: - Properties

    var sut: EditorPresenter!
    var mockCreateProject: MockCreateProjectUseCase!
    var mockGetProject: MockGetProjectUseCase!
    var mockUpdateProject: MockUpdateProjectUseCase!
    var mockGenerateAudio: MockGenerateAudioUseCase!
    var mockSaveAudioEntry: MockSaveAudioEntryUseCase!
    var mockTTSPort: MockTTSPort!
    var mockAudioPlayer: MockAudioPlayerPort!
    var mockAudioStorage: MockAudioStoragePort!
    var mockCaptureAndProcess: MockCaptureAndProcessUseCase!
    var mockProcessImageBatch: MockProcessImageBatchUseCase!
    var mockProcessDocument: MockProcessDocumentUseCase!
    var mockGenerateAudioForEntry: MockGenerateAudioForEntryUseCase!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockCreateProject = MockCreateProjectUseCase()
        mockGetProject = MockGetProjectUseCase()
        mockUpdateProject = MockUpdateProjectUseCase()
        mockGenerateAudio = MockGenerateAudioUseCase()
        mockSaveAudioEntry = MockSaveAudioEntryUseCase()
        mockTTSPort = MockTTSPort()
        mockAudioPlayer = MockAudioPlayerPort()
        mockAudioStorage = MockAudioStoragePort()
        mockCaptureAndProcess = MockCaptureAndProcessUseCase()
        mockProcessImageBatch = MockProcessImageBatchUseCase()
        mockProcessDocument = MockProcessDocumentUseCase()
        mockGenerateAudioForEntry = MockGenerateAudioForEntryUseCase()

        sut = EditorPresenter(
            createProjectUseCase: mockCreateProject,
            getProjectUseCase: mockGetProject,
            updateProjectUseCase: mockUpdateProject,
            generateAudioUseCase: mockGenerateAudio,
            saveAudioEntryUseCase: mockSaveAudioEntry,
            captureAndProcessUseCase: mockCaptureAndProcess,
            processImageBatchUseCase: mockProcessImageBatch,
            processDocumentUseCase: mockProcessDocument,
            generateAudioForEntryUseCase: mockGenerateAudioForEntry,
            ttsPort: mockTTSPort,
            audioPlayer: mockAudioPlayer,
            audioStorage: mockAudioStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockCreateProject = nil
        mockGetProject = nil
        mockUpdateProject = nil
        mockGenerateAudio = nil
        mockSaveAudioEntry = nil
        mockTTSPort = nil
        mockAudioPlayer = nil
        mockAudioStorage = nil
        mockCaptureAndProcess = nil
        mockProcessImageBatch = nil
        mockProcessDocument = nil
        mockGenerateAudioForEntry = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_shouldHaveDefaultViewModel() {
        // Assert
        XCTAssertNil(sut.viewModel.projectId)
        XCTAssertEqual(sut.viewModel.name, "")
        XCTAssertEqual(sut.viewModel.text, "")
        XCTAssertNil(sut.viewModel.selectedVoiceId)
        XCTAssertTrue(sut.viewModel.availableVoices.isEmpty)
        XCTAssertEqual(sut.viewModel.speed, 1.0)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertFalse(sut.viewModel.isGenerating)
        XCTAssertNil(sut.viewModel.error)
    }

    // MARK: - OnAppear Tests (New Project)

    func test_onAppear_withNilProjectId_shouldLoadVoices() async {
        // Arrange
        let testVoices = createTestVoices()
        mockTTSPort.voicesToReturn = testVoices.map { Voice(
            id: $0.id,
            name: $0.name,
            language: $0.language,
            provider: .native,
            isDefault: $0.isDefault
        )}

        // Act
        await sut.onAppear(projectId: nil)

        // Assert
        XCTAssertEqual(sut.viewModel.availableVoices.count, testVoices.count)
        XCTAssertNotNil(sut.viewModel.selectedVoiceId)
        XCTAssertFalse(sut.viewModel.isLoading)
    }

    func test_onAppear_withNilProjectId_shouldSelectDefaultVoice() async {
        // Arrange
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: false),
            Voice(id: "v2", name: "Voice 2", language: "en", provider: .native, isDefault: true),
            Voice(id: "v3", name: "Voice 3", language: "en", provider: .native, isDefault: false),
        ]

        // Act
        await sut.onAppear(projectId: nil)

        // Assert
        XCTAssertEqual(sut.viewModel.selectedVoiceId, "v2")
    }

    func test_onAppear_withNilProjectId_shouldSelectFirstIfNoDefault() async {
        // Arrange
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: false),
            Voice(id: "v2", name: "Voice 2", language: "en", provider: .native, isDefault: false),
        ]

        // Act
        await sut.onAppear(projectId: nil)

        // Assert
        XCTAssertEqual(sut.viewModel.selectedVoiceId, "v1")
    }

    // MARK: - OnAppear Tests (Existing Project)

    func test_onAppear_withProjectId_shouldLoadProject() async {
        // Arrange
        let projectId = Identifier<Project>()
        let testProject = createTestProject(id: projectId)
        mockGetProject.projectToReturn = testProject
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertEqual(sut.viewModel.projectId, projectId.value.uuidString)
        XCTAssertEqual(sut.viewModel.name, testProject.name.value)
        XCTAssertEqual(sut.viewModel.text, testProject.text?.value ?? "")
        XCTAssertEqual(sut.viewModel.selectedVoiceId, testProject.voiceConfiguration.voiceId)
        XCTAssertEqual(sut.viewModel.speed, testProject.voiceConfiguration.speed.value)
    }

    func test_onAppear_withProjectId_whenNotFound_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        mockGetProject.projectToReturn = nil
        mockTTSPort.voicesToReturn = []

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
        XCTAssertFalse(sut.viewModel.isLoading)
    }

    func test_onAppear_shouldSetLoadingDuringOperation() async {
        // Arrange
        mockTTSPort.delayResponse = true

        // Act
        let task = Task { await sut.onAppear(projectId: nil) }

        // Assert (verificar durante la carga)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockTTSPort.delayResponse = false
        await task.value
    }

    // MARK: - UpdateText Tests

    func test_updateText_shouldUpdateViewModel() {
        // Act
        sut.updateText("New text content")

        // Assert
        XCTAssertEqual(sut.viewModel.text, "New text content")
    }

    func test_updateText_shouldUpdateEstimatedDuration() {
        // Arrange
        let text = String(repeating: "word ", count: 150) // 150 palabras = ~1 minuto

        // Act
        sut.updateText(text)

        // Assert
        XCTAssertEqual(sut.viewModel.estimatedDuration, "1:00")
    }

    func test_updateText_withLongText_shouldCalculateCorrectDuration() {
        // Arrange
        let text = String(repeating: "word ", count: 300) // 300 palabras = ~2 minutos

        // Act
        sut.updateText(text)

        // Assert
        XCTAssertEqual(sut.viewModel.estimatedDuration, "2:00")
    }

    func test_updateText_withShortText_shouldShowSeconds() {
        // Arrange
        let text = String(repeating: "word ", count: 25) // 25 palabras = ~10 segundos

        // Act
        sut.updateText(text)

        // Assert
        XCTAssertEqual(sut.viewModel.estimatedDuration, "0:10")
    }

    // MARK: - UpdateName Tests

    func test_updateName_shouldUpdateViewModel() {
        // Act
        sut.updateName("Project Name")

        // Assert
        XCTAssertEqual(sut.viewModel.name, "Project Name")
    }

    // MARK: - SelectVoice Tests

    func test_selectVoice_shouldUpdateViewModel() {
        // Act
        sut.selectVoice("voice-id-123")

        // Assert
        XCTAssertEqual(sut.viewModel.selectedVoiceId, "voice-id-123")
    }

    // MARK: - UpdateSpeed Tests

    func test_updateSpeed_shouldUpdateViewModel() {
        // Act
        sut.updateSpeed(1.5)

        // Assert
        XCTAssertEqual(sut.viewModel.speed, 1.5)
    }

    // MARK: - Save Tests (New Project)

    func test_save_withNewProject_shouldCreateProject() async {
        // Arrange
        sut.updateName("My Project")
        sut.updateText("Hello world")
        sut.selectVoice("v1")

        let projectId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: projectId,
            projectName: "My Project",
            status: .draft,
            createdAt: Date()
        )

        // Act
        await sut.save()

        // Assert
        XCTAssertTrue(mockCreateProject.executeCalled)
        XCTAssertEqual(mockCreateProject.lastRequest?.name, "My Project")
        XCTAssertEqual(mockCreateProject.lastRequest?.text, "Hello world")
        XCTAssertEqual(sut.viewModel.projectId, projectId.value.uuidString)
        XCTAssertNil(sut.viewModel.error)
    }

    func test_save_withNewProject_shouldPassVoiceConfiguration() async {
        // Arrange
        sut.updateName("Test")
        sut.updateText("Content")
        sut.selectVoice("v2")
        sut.updateSpeed(1.5)

        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: Identifier<Project>(),
            projectName: "Test",
            status: .draft,
            createdAt: Date()
        )

        // Act
        await sut.save()

        // Assert
        XCTAssertEqual(mockCreateProject.lastRequest?.voiceId, "v2")
        XCTAssertEqual(mockCreateProject.lastRequest?.speed, 1.5)
    }

    func test_save_withNewProject_whenFails_shouldShowError() async {
        // Arrange
        sut.updateName("Test")
        sut.updateText("Content")
        sut.selectVoice("v1")

        mockCreateProject.errorToThrow = ApplicationError.projectNotFound

        // Act
        await sut.save()

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
        XCTAssertNil(sut.viewModel.projectId)
    }

    // MARK: - Save Tests (Existing Project)

    func test_save_withExistingProject_shouldUpdateProject() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Updated Name")
        sut.updateText("Updated text")
        sut.selectVoice("v3")

        mockUpdateProject.responseToReturn = UpdateProjectResponse(
            projectId: projectId,
            name: "Updated Name",
            text: "Updated text",
            status: .draft,
            audioPath: nil,
            voiceId: "v3",
            voiceName: "",
            voiceLanguage: "",
            voiceProvider: .native,
            speed: 1.0,
            updatedAt: Date()
        )

        // Act
        await sut.save()

        // Assert
        XCTAssertTrue(mockUpdateProject.executeCalled)
        XCTAssertEqual(mockUpdateProject.lastRequest?.projectId, projectId)
        XCTAssertEqual(mockUpdateProject.lastRequest?.name, "Updated Name")
        XCTAssertEqual(mockUpdateProject.lastRequest?.text, "Updated text")
    }

    func test_save_shouldSetLoadingDuringOperation() async {
        // Arrange
        sut.updateName("Test")
        sut.updateText("Content")
        sut.selectVoice("v1")
        mockCreateProject.delayResponse = true

        // Act
        let task = Task { await sut.save() }

        // Assert
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockCreateProject.delayResponse = false
        await task.value
    }

    // MARK: - GenerateAudio Tests (Entry-based)

    func test_generateAudio_shouldSynthesizeViaTTS() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertTrue(mockTTSPort.synthesizeCalled)
        XCTAssertNil(sut.viewModel.error)
    }

    func test_generateAudio_shouldCallSaveAudioEntryUseCase() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertTrue(mockSaveAudioEntry.executeCalled)
        XCTAssertEqual(mockSaveAudioEntry.lastRequest?.projectId, projectId)
        XCTAssertEqual(mockSaveAudioEntry.lastRequest?.text, "Test content for audio")
    }

    func test_generateAudio_shouldPassAudioDataToSaveEntry() async {
        // Arrange
        let projectId = Identifier<Project>()
        let audioBytes = Data(repeating: 42, count: 2048)
        setupForGenerateAudio(projectId: projectId, audioData: audioBytes, audioDuration: 15.0)

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertEqual(mockSaveAudioEntry.lastRequest?.audioData, audioBytes)
        XCTAssertEqual(mockSaveAudioEntry.lastRequest?.audioDuration, 15.0)
    }

    func test_generateAudio_shouldReloadEntriesAfterSave() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)

        // Configure mockGetProject to return project with 1 entry after save
        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertEqual(sut.viewModel.entries.count, 1)
        XCTAssertTrue(sut.viewModel.hasEntries)
    }

    func test_generateAudio_shouldAccumulateEntries() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)

        // After first generation, project has 1 entry
        let projectWith1Entry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWith1Entry

        await sut.generateAudio()
        XCTAssertEqual(sut.viewModel.entries.count, 1)

        // After second generation, project has 2 entries
        let projectWith2Entries = createTestProjectWithEntries(id: projectId, entryCount: 2)
        mockGetProject.projectToReturn = projectWith2Entries
        mockSaveAudioEntry.responseToReturn = SaveAudioEntryResponse(
            entryId: "002", entryNumber: 2,
            textPath: "General/002.txt", audioPath: "General/002.wav", imagePath: nil
        )

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertEqual(sut.viewModel.entries.count, 2)
    }

    func test_generateAudio_withoutProjectId_shouldSaveFirst() async {
        // Arrange
        sut.updateName("Test")
        sut.updateText("Content")

        let projectId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: projectId,
            projectName: "Test",
            status: .draft,
            createdAt: Date()
        )

        // Setup voice so TTS synthesis works
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]
        await sut.onAppear(projectId: nil)

        // Configure project reload after save
        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertTrue(mockCreateProject.executeCalled)
        XCTAssertTrue(mockSaveAudioEntry.executeCalled)
    }

    func test_generateAudio_shouldSetIsGeneratingTrue() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)
        mockSaveAudioEntry.delayResponse = true

        // Act
        let task = Task { await sut.generateAudio() }

        // Assert
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        XCTAssertTrue(sut.viewModel.isGenerating)

        // Cleanup
        mockSaveAudioEntry.delayResponse = false
        await task.value
    }

    func test_generateAudio_whenTTSFails_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)
        mockTTSPort.errorToThrow = NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthesis failed"])

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
        XCTAssertFalse(sut.viewModel.isGenerating)
    }

    func test_generateAudio_whenSaveEntryFails_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)
        mockSaveAudioEntry.errorToThrow = ApplicationError.projectNotFound

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
        XCTAssertFalse(sut.viewModel.isGenerating)
    }

    func test_generateAudio_whenSucceeds_shouldClearError() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)
        sut.viewModel.error = "Previous error"

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertNil(sut.viewModel.error)
    }

    func test_generateAudio_shouldShowSuccessWithDuration() async {
        // Arrange
        let projectId = Identifier<Project>()
        let audioBytes = Data(repeating: 1, count: 1024)
        setupForGenerateAudio(projectId: projectId, audioData: audioBytes, audioDuration: 65.0)

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertTrue(sut.viewModel.showAudioGeneratedSuccess)
        XCTAssertEqual(sut.viewModel.generatedAudioDuration, "1:05")
    }

    func test_generateAudio_shouldNotCallGenerateAudioUseCase() async {
        // Arrange - the old use case should NOT be called
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId)

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert - old use case NOT called, new flow used instead
        XCTAssertFalse(mockGenerateAudio.executeCalled)
        XCTAssertTrue(mockTTSPort.synthesizeCalled)
        XCTAssertTrue(mockSaveAudioEntry.executeCalled)
    }

    // MARK: - Playback Tests

    func test_loadAudio_shouldCallAudioPlayerLoad() async {
        // Arrange
        sut.viewModel.audioPath = "test_audio.wav"
        mockAudioPlayer.durationToReturn = 30.0
        mockAudioPlayer.samplesToReturn = [0.1, 0.5, 0.8]

        // Act
        await sut.loadAudio()

        // Assert
        XCTAssertTrue(mockAudioPlayer.loadCalled)
        XCTAssertEqual(sut.viewModel.audioDuration, 30.0)
        XCTAssertEqual(sut.viewModel.waveformSamples, [0.1, 0.5, 0.8])
    }

    func test_loadAudio_withNilPath_shouldNotCallPlayer() async {
        // Arrange
        sut.viewModel.audioPath = nil

        // Act
        await sut.loadAudio()

        // Assert
        XCTAssertFalse(mockAudioPlayer.loadCalled)
    }

    func test_play_shouldCallAudioPlayerPlay() async {
        // Act
        await sut.play()

        // Assert
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_pause_shouldCallAudioPlayerPause() async {
        // Act
        await sut.pause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
    }

    func test_togglePlayPause_whenPaused_shouldPlay() async {
        // Arrange
        sut.viewModel.isPlaying = false
        mockAudioPlayer.isPlayingToReturn = false

        // Act
        await sut.togglePlayPause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.playCalled)
        XCTAssertFalse(mockAudioPlayer.pauseCalled)
    }

    func test_togglePlayPause_whenPlaying_shouldPause() async {
        // Arrange
        sut.viewModel.isPlaying = true

        // Act
        await sut.togglePlayPause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
        XCTAssertFalse(mockAudioPlayer.playCalled)
    }

    func test_seek_shouldSeekToCorrectTime() async {
        // Arrange
        sut.viewModel.audioDuration = 100.0

        // Act
        await sut.seek(to: 0.5)

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 50.0, accuracy: 0.01)
    }

    func test_seek_shouldClampProgress() async {
        // Arrange
        sut.viewModel.audioDuration = 100.0

        // Act
        await sut.seek(to: 1.5)

        // Assert
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 100.0, accuracy: 0.01)
    }

    func test_skipBackward_shouldSeekBackward10Seconds() async {
        // Arrange
        sut.viewModel.currentTime = 25.0

        // Act
        await sut.skipBackward()

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 15.0, accuracy: 0.01)
    }

    func test_skipBackward_shouldNotGoBelowZero() async {
        // Arrange
        sut.viewModel.currentTime = 5.0

        // Act
        await sut.skipBackward()

        // Assert
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 0.0, accuracy: 0.01)
    }

    func test_skipForward_shouldSeekForward10Seconds() async {
        // Arrange
        sut.viewModel.currentTime = 20.0
        sut.viewModel.audioDuration = 100.0

        // Act
        await sut.skipForward()

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 30.0, accuracy: 0.01)
    }

    func test_skipForward_shouldNotExceedDuration() async {
        // Arrange
        sut.viewModel.currentTime = 95.0
        sut.viewModel.audioDuration = 100.0

        // Act
        await sut.skipForward()

        // Assert
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 100.0, accuracy: 0.01)
    }

    func test_setPlaybackSpeed_shouldUpdateRate() async {
        // Act
        await sut.setPlaybackSpeed(1.5)

        // Assert
        XCTAssertTrue(mockAudioPlayer.setRateCalled)
        XCTAssertEqual(mockAudioPlayer.lastRate, 1.5)
        XCTAssertEqual(sut.viewModel.playbackSpeed, 1.5)
    }

    func test_setPlaybackSpeed_shouldClampToRange() async {
        // Act
        await sut.setPlaybackSpeed(3.0)

        // Assert
        XCTAssertEqual(mockAudioPlayer.lastRate, 2.0)
    }

    func test_stopPlayback_shouldStopPlayer() async {
        // Act
        await sut.stopPlayback()

        // Assert
        XCTAssertTrue(mockAudioPlayer.stopCalled)
        XCTAssertFalse(sut.viewModel.isPlaying)
        XCTAssertEqual(sut.viewModel.currentTime, 0)
    }

    func test_generateAudio_shouldCreateEntryWithCorrectText() async {
        // Arrange
        let projectId = Identifier<Project>()
        setupForGenerateAudio(projectId: projectId, text: "Mi texto de prueba")

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.generateAudio()

        // Assert
        XCTAssertEqual(mockSaveAudioEntry.lastRequest?.text, "Mi texto de prueba")
    }

    func test_updatePlaybackState_shouldSyncFromPlayer() async {
        // Arrange
        mockAudioPlayer.currentTimeToReturn = 15.0
        mockAudioPlayer.isPlayingToReturn = true

        // Act
        await sut.updatePlaybackState()

        // Assert
        XCTAssertEqual(sut.viewModel.currentTime, 15.0)
        XCTAssertTrue(sut.viewModel.isPlaying)
    }

    // MARK: - Integration Tests

    func test_fullFlow_createSaveGenerateEntry() async {
        // 1. Cargar voces
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]
        await sut.onAppear(projectId: nil)
        XCTAssertEqual(sut.viewModel.availableVoices.count, 1)

        // 2. Editar contenido
        sut.updateName("Integration Test")
        sut.updateText("This is a test")
        XCTAssertTrue(sut.viewModel.canSave)

        // 3. Guardar proyecto
        let projectId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: projectId,
            projectName: "Integration Test",
            status: .draft,
            createdAt: Date()
        )
        await sut.save()
        XCTAssertNotNil(sut.viewModel.projectId)

        // 4. Generar audio como entry
        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        await sut.generateAudio()

        // Assert - TTS synthesis + entry save, NOT old generate use case
        XCTAssertTrue(mockTTSPort.synthesizeCalled)
        XCTAssertTrue(mockSaveAudioEntry.executeCalled)
        XCTAssertFalse(mockGenerateAudio.executeCalled)
        XCTAssertEqual(sut.viewModel.entries.count, 1)
    }

    // MARK: - Helper Methods

    private func createTestVoices() -> [VoiceDTO] {
        [
            VoiceDTO(id: "v1", name: "Voice 1", language: "en-US", provider: "native", isDefault: true),
            VoiceDTO(id: "v2", name: "Voice 2", language: "en-GB", provider: "native", isDefault: false),
        ]
    }

    private func createTestProject(id: Identifier<Project>) -> Project {
        Project(
            id: id,
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Test content"),
            voiceConfiguration: VoiceConfiguration(
                voiceId: "v1",
                speed: try! VoiceConfiguration.Speed(1.0)
            ),
            voice: Voice(id: "v1", name: "Test Voice", language: "en", provider: .native, isDefault: false),
            audioPath: nil,
            status: .draft,
            entries: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Auto-Save Tests

    func test_init_shouldHaveIdleAutoSaveState() {
        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .idle)
    }

    func test_updateText_withExistingProject_shouldScheduleAutoSave() {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Test")

        // Act
        sut.updateText("New text")

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)
    }

    func test_updateText_withNewProject_shouldNotScheduleAutoSave() {
        // Arrange - no projectId (new project)

        // Act
        sut.updateText("New text")

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .idle)
    }

    func test_updateName_withExistingProject_shouldScheduleAutoSave() {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Act
        sut.updateName("New name")

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)
    }

    func test_updateName_withNewProject_shouldNotScheduleAutoSave() {
        // Arrange - no projectId

        // Act
        sut.updateName("New name")

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .idle)
    }

    func test_selectVoice_withExistingProject_shouldScheduleAutoSave() {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Act
        sut.selectVoice("new-voice-id")

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)
    }

    func test_updateSpeed_withExistingProject_shouldScheduleAutoSave() {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Act
        sut.updateSpeed(1.5)

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)
    }

    func test_autoSave_afterDebounce_shouldUpdateProject() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Test Project")

        mockUpdateProject.responseToReturn = UpdateProjectResponse(
            projectId: projectId,
            name: "Test Project",
            text: "Updated",
            status: .draft,
            audioPath: nil,
            voiceId: "v1",
            voiceName: "",
            voiceLanguage: "",
            voiceProvider: .native,
            speed: 1.0,
            updatedAt: Date()
        )

        // Act
        sut.updateText("Updated")

        // Wait for debounce (2 seconds + buffer)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Assert
        XCTAssertTrue(mockUpdateProject.executeCalled)
    }

    func test_autoSave_afterDebounce_shouldTransitionToSaved() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Test Project")

        mockUpdateProject.responseToReturn = UpdateProjectResponse(
            projectId: projectId,
            name: "Test Project",
            text: "Saved text",
            status: .draft,
            audioPath: nil,
            voiceId: "v1",
            voiceName: "",
            voiceLanguage: "",
            voiceProvider: .native,
            speed: 1.0,
            updatedAt: Date()
        )

        // Act
        sut.updateText("Saved text")
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)

        // Wait for debounce + save to complete
        try await Task.sleep(nanoseconds: 2_800_000_000)

        // Assert
        XCTAssertTrue(
            sut.viewModel.autoSaveState == .saved || sut.viewModel.autoSaveState == .idle,
            "Expected .saved or .idle, got \(sut.viewModel.autoSaveState)"
        )
        XCTAssertTrue(mockUpdateProject.executeCalled)
    }

    func test_autoSave_whenFails_shouldResetToIdleAndShowError() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Test Project")

        mockUpdateProject.errorToThrow = ApplicationError.projectNotFound

        // Act
        sut.updateText("Will fail")

        // Wait for debounce + error
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Assert
        XCTAssertEqual(sut.viewModel.autoSaveState, .idle)
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_onDisappear_shouldCancelPendingAutoSave() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Trigger auto-save schedule
        sut.updateText("Pending save")
        XCTAssertEqual(sut.viewModel.autoSaveState, .pending)

        // Act
        await sut.onDisappear()

        // Wait past debounce interval - save should NOT fire
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        // Assert
        XCTAssertFalse(mockUpdateProject.executeCalled)
    }

    func test_autoSave_multipleChanges_shouldDebounce() async throws {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        mockUpdateProject.responseToReturn = UpdateProjectResponse(
            projectId: projectId,
            name: "Final",
            text: "Final text",
            status: .draft,
            audioPath: nil,
            voiceId: "v1",
            voiceName: "",
            voiceLanguage: "",
            voiceProvider: .native,
            speed: 1.0,
            updatedAt: Date()
        )

        // Act - multiple rapid changes
        sut.updateName("First")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        sut.updateName("Second")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        sut.updateName("Final")

        // Wait less than debounce - should NOT have saved yet
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        XCTAssertFalse(mockUpdateProject.executeCalled)

        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s more

        // Assert - only one save with final values
        XCTAssertTrue(mockUpdateProject.executeCalled)
        XCTAssertEqual(mockUpdateProject.lastRequest?.name, "Final")
    }

    // MARK: - Audio Entries Tests

    func test_init_shouldHaveEmptyEntries() {
        // Assert
        XCTAssertTrue(sut.viewModel.entries.isEmpty)
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertFalse(sut.viewModel.hasEntries)
    }

    func test_onAppear_withProjectWithEntries_shouldPopulateEntries() async {
        // Arrange
        let projectId = Identifier<Project>()
        let projectWithEntries = createTestProjectWithEntries(id: projectId, entryCount: 3)
        mockGetProject.projectToReturn = projectWithEntries
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertEqual(sut.viewModel.entries.count, 3)
        XCTAssertTrue(sut.viewModel.hasEntries)
    }

    func test_onAppear_withProjectWithEntries_shouldMapEntryNumbers() async {
        // Arrange
        let projectId = Identifier<Project>()
        let projectWithEntries = createTestProjectWithEntries(id: projectId, entryCount: 2)
        mockGetProject.projectToReturn = projectWithEntries
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertEqual(sut.viewModel.entries[0].number, 1)
        XCTAssertEqual(sut.viewModel.entries[1].number, 2)
        XCTAssertEqual(sut.viewModel.entries[0].formattedNumber, "001")
        XCTAssertEqual(sut.viewModel.entries[1].formattedNumber, "002")
    }

    func test_onAppear_withProjectWithEntries_shouldIncludeTextPreview() async {
        // Arrange
        let projectId = Identifier<Project>()
        let projectWithEntries = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntries
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertFalse(sut.viewModel.entries[0].textPreview.isEmpty)
    }

    func test_playEntry_shouldSetPlayingEntryId() async {
        // Arrange
        let projectId = Identifier<Project>()
        let projectWithEntries = createTestProjectWithEntries(id: projectId, entryCount: 2)
        mockGetProject.projectToReturn = projectWithEntries
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]
        mockAudioPlayer.durationToReturn = 5.0
        mockAudioPlayer.samplesToReturn = [0.1, 0.2]

        await sut.onAppear(projectId: projectId)
        let entryId = sut.viewModel.entries[0].id

        // Act
        await sut.playEntry(id: entryId)

        // Assert
        XCTAssertEqual(sut.viewModel.playingEntryId, entryId)
    }

    func test_playEntry_shouldLoadAudioForEntry() async {
        // Arrange
        let projectId = Identifier<Project>()
        let projectWithEntries = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntries
        mockTTSPort.voicesToReturn = [
            Voice(id: "v1", name: "Voice 1", language: "en", provider: .native, isDefault: true)
        ]
        mockAudioPlayer.durationToReturn = 5.0
        mockAudioPlayer.samplesToReturn = [0.1, 0.2]

        await sut.onAppear(projectId: projectId)
        let entryId = sut.viewModel.entries[0].id

        // Act
        await sut.playEntry(id: entryId)

        // Assert
        XCTAssertTrue(mockAudioPlayer.loadCalled)
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_stopEntry_shouldClearPlayingEntryId() async {
        // Arrange
        sut.viewModel.playingEntryId = "some-entry-id"

        // Act
        await sut.stopEntry()

        // Assert
        XCTAssertNil(sut.viewModel.playingEntryId)
    }

    // MARK: - GenerateAudio Helper

    /// Sets up presenter state and mocks for generateAudio tests
    private func setupForGenerateAudio(
        projectId: Identifier<Project>,
        text: String = "Test content for audio",
        audioData: Data? = nil,
        audioDuration: TimeInterval = 10.0
    ) {
        // Set viewModel state
        sut.viewModel.projectId = projectId.value.uuidString
        sut.updateName("Test Project")
        sut.updateText(text)

        // Configure voices so TTS can find the selected voice
        sut.viewModel.availableVoices = [
            VoiceDTO(id: "v1", name: "Voice 1", language: "en", provider: "native", isDefault: true)
        ]
        sut.viewModel.selectedVoiceId = "v1"

        // Configure TTS mock
        let bytes = audioData ?? Data(repeating: 1, count: 1024)
        mockTTSPort.audioDataToReturn = try! AudioData(data: bytes, duration: audioDuration)

        // Configure update mock (called before synthesis)
        mockUpdateProject.responseToReturn = UpdateProjectResponse(
            projectId: projectId,
            name: "Test Project",
            text: text,
            status: .draft,
            audioPath: nil,
            voiceId: "v1",
            voiceName: "Voice 1",
            voiceLanguage: "en",
            voiceProvider: .native,
            speed: 1.0,
            updatedAt: Date()
        )

        // Configure save entry mock
        mockSaveAudioEntry.responseToReturn = SaveAudioEntryResponse(
            entryId: "001",
            entryNumber: 1,
            textPath: "General/001.txt",
            audioPath: "General/001.wav",
            imagePath: nil
        )

        // Configure get project mock for reload
        // (default: empty entries - tests can override this)
        mockGetProject.projectToReturn = createTestProjectWithEntries(id: projectId, entryCount: 0)
    }

    // MARK: - CaptureScreen Tests

    func test_captureScreen_shouldCallCaptureAndProcessUseCase() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertTrue(mockCaptureAndProcess.executeCalled)
        XCTAssertEqual(mockCaptureAndProcess.lastRequest?.projectId, projectId)
    }

    func test_captureScreen_shouldPassGenerateAudioFalseByDefault() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertEqual(mockCaptureAndProcess.lastRequest?.generateAudio, false)
    }

    func test_captureScreen_shouldReloadEntriesAfterSuccess() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        mockCaptureAndProcess.responseToReturn = CaptureAndProcessResponse(
            recognizedText: "Captured text",
            confidence: 0.9,
            entryId: "001",
            entryNumber: 1,
            imagePath: "/tmp/capture.png",
            audioPath: nil
        )

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertEqual(sut.viewModel.entries.count, 1)
    }

    func test_captureScreen_shouldUpdateTextWithRecognizedText() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        mockCaptureAndProcess.responseToReturn = CaptureAndProcessResponse(
            recognizedText: "Texto reconocido por OCR",
            confidence: 0.95,
            entryId: "001",
            entryNumber: 1,
            imagePath: nil,
            audioPath: nil
        )

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertEqual(sut.viewModel.text, "Texto reconocido por OCR")
    }

    func test_captureScreen_whenUserCancels_shouldNotShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        mockCaptureAndProcess.errorToThrow = ScreenCaptureError.userCancelled

        // Act
        await sut.captureScreen()

        // Assert - cancellation is not an error
        XCTAssertNil(sut.viewModel.error)
    }

    func test_captureScreen_whenOCRFails_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        mockCaptureAndProcess.errorToThrow = OCRError.noTextFound

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_captureScreen_shouldSetIsCapturingDuringOperation() async {
        // Arrange
        let projectId = Identifier<Project>()
        sut.viewModel.projectId = projectId.value.uuidString
        mockCaptureAndProcess.delayResponse = true

        // Act
        let task = Task { await sut.captureScreen() }

        // Assert (during capture)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        XCTAssertTrue(sut.viewModel.isCapturing)

        // Cleanup
        mockCaptureAndProcess.delayResponse = false
        await task.value
        XCTAssertFalse(sut.viewModel.isCapturing)
    }

    func test_captureScreen_withoutProjectId_shouldSaveProjectFirst() async {
        // Arrange - no projectId (new project)
        sut.updateName("New Project")
        sut.updateText("")

        let projectId = Identifier<Project>()
        mockCreateProject.responseToReturn = CreateProjectResponse(
            projectId: projectId,
            projectName: "New Project",
            status: .draft,
            createdAt: Date()
        )

        let projectWithEntry = createTestProjectWithEntries(id: projectId, entryCount: 1)
        mockGetProject.projectToReturn = projectWithEntry

        // Act
        await sut.captureScreen()

        // Assert
        XCTAssertTrue(mockCreateProject.executeCalled)
        XCTAssertTrue(mockCaptureAndProcess.executeCalled)
    }

    // MARK: - Additional Helper Methods

    private func createTestProjectWithEntries(id: Identifier<Project>, entryCount: Int) -> Project {
        var entries: [AudioEntry] = []
        if entryCount > 0 {
            for i in 1...entryCount {
                let entry = AudioEntry(
                    id: EntryId(),
                    text: try! TextContent("Entry \(i) text content for testing"),
                    audioPath: "audio/\(String(format: "%03d", i)).wav",
                    imagePath: i % 2 == 0 ? nil : "images/\(String(format: "%03d", i)).png",
                    createdAt: Date()
                )
                entries.append(entry)
            }
        }

        return Project(
            id: id,
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Test content"),
            voiceConfiguration: VoiceConfiguration(
                voiceId: "v1",
                speed: try! VoiceConfiguration.Speed(1.0)
            ),
            voice: Voice(id: "v1", name: "Test Voice", language: "en", provider: .native, isDefault: false),
            audioPath: nil,
            status: .draft,
            entries: entries,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

