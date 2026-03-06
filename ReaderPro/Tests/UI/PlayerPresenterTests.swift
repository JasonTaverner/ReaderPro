import XCTest
@testable import ReaderPro

/// Tests para PlayerPresenter usando TDD
@MainActor
final class PlayerPresenterTests: XCTestCase {

    // MARK: - Properties

    var sut: PlayerPresenter!
    var mockGetProject: MockGetProjectUseCase!
    var mockAudioPlayer: MockAudioPlayerPort!
    var mockAudioStorage: MockAudioStoragePort!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockGetProject = MockGetProjectUseCase()
        mockAudioPlayer = MockAudioPlayerPort()
        mockAudioStorage = MockAudioStoragePort()

        sut = PlayerPresenter(
            getProjectUseCase: mockGetProject,
            audioPlayer: mockAudioPlayer,
            audioStorage: mockAudioStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockGetProject = nil
        mockAudioPlayer = nil
        mockAudioStorage = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_shouldHaveDefaultViewModel() {
        // Assert
        XCTAssertNil(sut.viewModel.projectId)
        XCTAssertEqual(sut.viewModel.projectName, "")
        XCTAssertFalse(sut.viewModel.isPlaying)
        XCTAssertEqual(sut.viewModel.currentTime, 0)
        XCTAssertEqual(sut.viewModel.duration, 0)
        XCTAssertEqual(sut.viewModel.playbackSpeed, 1.0)
        XCTAssertTrue(sut.viewModel.waveformSamples.isEmpty)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNil(sut.viewModel.error)
    }

    // MARK: - OnAppear Tests

    func test_onAppear_shouldLoadProject() async {
        // Arrange
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.durationToReturn = 10.5
        mockAudioPlayer.samplesToReturn = [0.5, 0.8, 0.3]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertEqual(sut.viewModel.projectId, projectId.value.uuidString)
        XCTAssertEqual(sut.viewModel.projectName, project.name.value)
        XCTAssertFalse(sut.viewModel.isLoading)
        XCTAssertNil(sut.viewModel.error)
    }

    func test_onAppear_shouldLoadAudio() async {
        // Arrange
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.durationToReturn = 15.0

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertTrue(mockAudioPlayer.loadCalled)
        XCTAssertEqual(sut.viewModel.duration, 15.0)
    }

    func test_onAppear_shouldGenerateWaveform() async {
        // Arrange
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.samplesToReturn = [0.1, 0.2, 0.3, 0.4, 0.5]

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertEqual(sut.viewModel.waveformSamples.count, 5)
        XCTAssertEqual(sut.viewModel.waveformSamples, [0.1, 0.2, 0.3, 0.4, 0.5])
    }

    func test_onAppear_whenProjectNotFound_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        mockGetProject.projectToReturn = nil

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
        XCTAssertFalse(sut.viewModel.isLoading)
    }

    func test_onAppear_whenNoAudioPath_shouldShowError() async {
        // Arrange
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: nil)
        mockGetProject.projectToReturn = project

        // Act
        await sut.onAppear(projectId: projectId)

        // Assert
        XCTAssertNotNil(sut.viewModel.error)
    }

    func test_onAppear_shouldSetLoadingDuringOperation() async {
        // Arrange
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.delayResponse = true

        // Act
        let task = Task { await sut.onAppear(projectId: projectId) }

        // Assert
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.viewModel.isLoading)

        // Cleanup
        mockAudioPlayer.delayResponse = false
        await task.value
    }

    // MARK: - Play Tests

    func test_play_shouldStartPlayback() async {
        // Arrange
        await loadTestProject()

        // Act
        await sut.play()

        // Assert
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_play_shouldUpdateIsPlaying() async {
        // Arrange
        await loadTestProject()
        mockAudioPlayer.isPlayingToReturn = true

        // Act
        await sut.play()

        // Assert
        XCTAssertTrue(sut.viewModel.isPlaying)
    }

    // MARK: - Pause Tests

    func test_pause_shouldStopPlayback() async {
        // Arrange
        await loadTestProject()
        await sut.play()

        // Act
        await sut.pause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
    }

    func test_pause_shouldUpdateIsPlaying() async {
        // Arrange
        await loadTestProject()
        await sut.play()
        mockAudioPlayer.isPlayingToReturn = false

        // Act
        await sut.pause()

        // Assert
        XCTAssertFalse(sut.viewModel.isPlaying)
    }

    // MARK: - TogglePlayPause Tests

    func test_togglePlayPause_whenPaused_shouldPlay() async {
        // Arrange
        await loadTestProject()
        mockAudioPlayer.isPlayingToReturn = false

        // Act
        await sut.togglePlayPause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_togglePlayPause_whenPlaying_shouldPause() async {
        // Arrange
        await loadTestProject()
        mockAudioPlayer.isPlayingToReturn = true
        sut.viewModel.isPlaying = true

        // Act
        await sut.togglePlayPause()

        // Assert
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
    }

    // MARK: - Seek Tests

    func test_seek_shouldCallAudioPlayer() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0

        // Act
        await sut.seek(to: 0.5) // 50% = 50 seconds

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 50.0, accuracy: 0.1)
    }

    func test_seek_shouldClampToValidRange() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0

        // Act - Seek beyond duration
        await sut.seek(to: 1.5) // 150%

        // Assert
        XCTAssertLessThanOrEqual(mockAudioPlayer.lastSeekTime ?? 0, 100.0)
    }

    func test_seek_shouldUpdateCurrentTime() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0
        mockAudioPlayer.currentTimeToReturn = 25.0

        // Act
        await sut.seek(to: 0.25)

        // Assert
        XCTAssertEqual(sut.viewModel.currentTime, 25.0)
    }

    // MARK: - Skip Tests

    func test_skipBackward_shouldSeekBack10Seconds() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0
        mockAudioPlayer.currentTimeToReturn = 30.0
        sut.viewModel.currentTime = 30.0

        // Act
        await sut.skipBackward()

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 20.0, accuracy: 0.1)
    }

    func test_skipBackward_atBeginning_shouldSeekTo0() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0
        mockAudioPlayer.currentTimeToReturn = 5.0
        sut.viewModel.currentTime = 5.0

        // Act
        await sut.skipBackward()

        // Assert
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 0, accuracy: 0.1)
    }

    func test_skipForward_shouldSeekForward10Seconds() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0
        mockAudioPlayer.currentTimeToReturn = 30.0
        sut.viewModel.currentTime = 30.0

        // Act
        await sut.skipForward()

        // Assert
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime!, 40.0, accuracy: 0.1)
    }

    func test_skipForward_nearEnd_shouldClampToDuration() async {
        // Arrange
        await loadTestProject()
        sut.viewModel.duration = 100.0
        mockAudioPlayer.currentTimeToReturn = 96.0
        sut.viewModel.currentTime = 96.0

        // Act
        await sut.skipForward()

        // Assert
        XCTAssertLessThanOrEqual(mockAudioPlayer.lastSeekTime ?? 0, 100.0)
    }

    // MARK: - SetSpeed Tests

    func test_setSpeed_shouldCallAudioPlayer() async {
        // Arrange
        await loadTestProject()

        // Act
        await sut.setSpeed(1.5)

        // Assert
        XCTAssertTrue(mockAudioPlayer.setRateCalled)
        XCTAssertEqual(mockAudioPlayer.lastRate, 1.5)
    }

    func test_setSpeed_shouldUpdateViewModel() async {
        // Arrange
        await loadTestProject()
        mockAudioPlayer.rateToReturn = 2.0

        // Act
        await sut.setSpeed(2.0)

        // Assert
        XCTAssertEqual(sut.viewModel.playbackSpeed, 2.0)
    }

    func test_setSpeed_shouldClampTo0_5_2_0Range() async {
        // Arrange
        await loadTestProject()

        // Act - Try to set below minimum
        await sut.setSpeed(0.3)

        // Assert
        XCTAssertGreaterThanOrEqual(mockAudioPlayer.lastRate ?? 0, 0.5)

        // Act - Try to set above maximum
        await sut.setSpeed(3.0)

        // Assert
        XCTAssertLessThanOrEqual(mockAudioPlayer.lastRate ?? 0, 2.0)
    }

    // MARK: - UpdatePlaybackState Tests

    func test_updatePlaybackState_shouldSyncWithAudioPlayer() async {
        // Arrange
        await loadTestProject()
        mockAudioPlayer.currentTimeToReturn = 45.5
        mockAudioPlayer.isPlayingToReturn = true

        // Act
        await sut.updatePlaybackState()

        // Assert
        XCTAssertEqual(sut.viewModel.currentTime, 45.5)
        XCTAssertTrue(sut.viewModel.isPlaying)
    }

    // MARK: - OnDisappear Tests

    func test_onDisappear_shouldStopPlayback() async {
        // Arrange
        await loadTestProject()
        await sut.play()

        // Act
        await sut.onDisappear()

        // Assert
        XCTAssertTrue(mockAudioPlayer.stopCalled)
    }

    // MARK: - Integration Tests

    func test_fullPlaybackFlow() async {
        // 1. Load project
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.durationToReturn = 100.0

        await sut.onAppear(projectId: projectId)
        XCTAssertEqual(sut.viewModel.duration, 100.0)

        // 2. Play
        mockAudioPlayer.isPlayingToReturn = true
        await sut.play()
        XCTAssertTrue(sut.viewModel.isPlaying)

        // 3. Seek to middle
        mockAudioPlayer.currentTimeToReturn = 50.0
        await sut.seek(to: 0.5)
        XCTAssertEqual(sut.viewModel.currentTime, 50.0)

        // 4. Change speed
        mockAudioPlayer.rateToReturn = 1.5
        await sut.setSpeed(1.5)
        XCTAssertEqual(sut.viewModel.playbackSpeed, 1.5)

        // 5. Pause
        mockAudioPlayer.isPlayingToReturn = false
        await sut.pause()
        XCTAssertFalse(sut.viewModel.isPlaying)

        // 6. Cleanup
        await sut.onDisappear()
        XCTAssertTrue(mockAudioPlayer.stopCalled)
    }

    // MARK: - Helper Methods

    private func createTestProject(
        id: Identifier<Project>,
        audioPath: String?
    ) -> Project {
        Project(
            id: id,
            name: try! ProjectName("Test Project"),
            text: try! TextContent("Test content"),
            voiceConfiguration: VoiceConfiguration(
                voiceId: "v1",
                speed: try! VoiceConfiguration.Speed(1.0)
            ),
            voice: Voice(id: "v1", name: "Test Voice", language: "en", provider: .native, isDefault: false),
            audioPath: audioPath,
            status: .ready,
            entries: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func loadTestProject() async {
        let projectId = Identifier<Project>()
        let project = createTestProject(id: projectId, audioPath: "/audio/test.wav")
        mockGetProject.projectToReturn = project
        // audioStorage.baseDirectory is used by presenter to build full path
        mockAudioPlayer.durationToReturn = 100.0

        await sut.onAppear(projectId: projectId)
    }
}
