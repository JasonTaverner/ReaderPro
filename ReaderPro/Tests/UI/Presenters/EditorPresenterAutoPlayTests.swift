import XCTest
@testable import ReaderPro

/// Tests for auto-play functionality in EditorPresenter
@MainActor
final class EditorPresenterAutoPlayTests: XCTestCase {

    // MARK: - Properties

    var sut: EditorPresenter!
    var mockAudioPlayer: MockAudioPlayerPort!
    var mockCreateProject: MockCreateProjectUseCase!
    var mockGetProject: MockGetProjectUseCase!
    var mockUpdateProject: MockUpdateProjectUseCase!
    var mockGenerateAudio: MockGenerateAudioUseCase!
    var mockSaveAudioEntry: MockSaveAudioEntryUseCase!
    var mockCaptureAndProcess: MockCaptureAndProcessUseCase!
    var mockProcessImageBatch: MockProcessImageBatchUseCase!
    var mockProcessDocument: MockProcessDocumentUseCase!
    var mockGenerateAudioForEntry: MockGenerateAudioForEntryUseCase!
    var mockTTSPort: MockTTSPort!
    var mockAudioStorage: MockAudioStoragePort!

    // MARK: - Setup

    override func setUp() async throws {
        mockAudioPlayer = MockAudioPlayerPort()
        mockCreateProject = MockCreateProjectUseCase()
        mockGetProject = MockGetProjectUseCase()
        mockUpdateProject = MockUpdateProjectUseCase()
        mockGenerateAudio = MockGenerateAudioUseCase()
        mockSaveAudioEntry = MockSaveAudioEntryUseCase()
        mockCaptureAndProcess = MockCaptureAndProcessUseCase()
        mockProcessImageBatch = MockProcessImageBatchUseCase()
        mockProcessDocument = MockProcessDocumentUseCase()
        mockGenerateAudioForEntry = MockGenerateAudioForEntryUseCase()
        mockTTSPort = MockTTSPort()
        mockAudioStorage = MockAudioStoragePort()

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

    override func tearDown() async throws {
        sut = nil
        mockAudioPlayer = nil
    }

    // MARK: - Auto-Play Toggle Tests

    func test_toggleAutoPlay_whenDisabled_shouldEnable() {
        // Arrange
        XCTAssertFalse(sut.viewModel.isAutoPlayEnabled)

        // Act
        sut.toggleAutoPlay()

        // Assert
        XCTAssertTrue(sut.viewModel.isAutoPlayEnabled)
    }

    func test_toggleAutoPlay_whenEnabled_shouldDisable() {
        // Arrange
        sut.toggleAutoPlay() // Enable first
        XCTAssertTrue(sut.viewModel.isAutoPlayEnabled)

        // Act
        sut.toggleAutoPlay()

        // Assert
        XCTAssertFalse(sut.viewModel.isAutoPlayEnabled)
    }

    // MARK: - Play Next Tests

    func test_playNext_withMultipleEntries_shouldPlayNextEntry() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0
        mockAudioPlayer.durationToReturn = 10.0

        // Act
        await sut.playNext()

        // Assert
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 1)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[1].id)
        XCTAssertTrue(mockAudioPlayer.loadCalled)
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_playNext_atLastEntry_shouldStopPlayback() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = sut.viewModel.entries[2].id
        sut.viewModel.currentPlayingIndex = 2

        // Act
        await sut.playNext()

        // Assert
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, -1)
    }

    func test_playNext_withNoPlayingEntry_shouldDoNothing() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = nil
        sut.viewModel.currentPlayingIndex = -1

        // Act
        await sut.playNext()

        // Assert
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertFalse(mockAudioPlayer.playCalled)
    }

    func test_playNext_skipsEntriesWithoutAudio() async {
        // Arrange
        setupViewModelWithEntries(count: 3, audioAtIndices: [0, 2]) // Entry 1 has no audio
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0
        mockAudioPlayer.durationToReturn = 10.0

        // Act
        await sut.playNext()

        // Assert - Should skip entry 1 and play entry 2
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 2)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[2].id)
    }

    // MARK: - Play Previous Tests

    func test_playPrevious_withMultipleEntries_shouldPlayPreviousEntry() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = sut.viewModel.entries[2].id
        sut.viewModel.currentPlayingIndex = 2
        mockAudioPlayer.durationToReturn = 10.0

        // Act
        await sut.playPrevious()

        // Assert
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 1)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[1].id)
        XCTAssertTrue(mockAudioPlayer.loadCalled)
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func test_playPrevious_atFirstEntry_shouldRestartCurrentEntry() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0
        mockAudioPlayer.durationToReturn = 10.0

        // Act
        await sut.playPrevious()

        // Assert - Should restart first entry
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 0)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[0].id)
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime, 0)
    }

    func test_playPrevious_skipsEntriesWithoutAudio() async {
        // Arrange
        setupViewModelWithEntries(count: 3, audioAtIndices: [0, 2]) // Entry 1 has no audio
        sut.viewModel.playingEntryId = sut.viewModel.entries[2].id
        sut.viewModel.currentPlayingIndex = 2
        mockAudioPlayer.durationToReturn = 10.0

        // Act
        await sut.playPrevious()

        // Assert - Should skip entry 1 and play entry 0
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 0)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[0].id)
    }

    // MARK: - Auto-Play on Completion Tests

    func test_onPlaybackComplete_withAutoPlayEnabled_shouldPlayNext() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.isAutoPlayEnabled = true
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0
        mockAudioPlayer.durationToReturn = 10.0

        // Act - Simulate playback completion
        await sut.handlePlaybackCompletion()

        // Assert
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 1)
        XCTAssertEqual(sut.viewModel.playingEntryId, sut.viewModel.entries[1].id)
    }

    func test_onPlaybackComplete_withAutoPlayDisabled_shouldNotPlayNext() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.isAutoPlayEnabled = false
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0

        // Act - Simulate playback completion
        await sut.handlePlaybackCompletion()

        // Assert - Should stop, not play next
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, -1)
    }

    func test_onPlaybackComplete_atLastEntry_shouldStopEvenWithAutoPlay() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.isAutoPlayEnabled = true
        sut.viewModel.playingEntryId = sut.viewModel.entries[2].id
        sut.viewModel.currentPlayingIndex = 2

        // Act - Simulate playback completion
        await sut.handlePlaybackCompletion()

        // Assert - Should stop since no more entries
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, -1)
    }

    // MARK: - Current Playing Index Tests

    func test_playEntry_shouldSetCurrentPlayingIndex() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        mockAudioPlayer.durationToReturn = 10.0
        let entryId = sut.viewModel.entries[1].id

        // Act
        await sut.playEntry(id: entryId)

        // Assert
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, 1)
        XCTAssertEqual(sut.viewModel.playingEntryId, entryId)
    }

    func test_stopEntry_shouldResetCurrentPlayingIndex() async {
        // Arrange
        setupViewModelWithEntries(count: 3)
        sut.viewModel.playingEntryId = sut.viewModel.entries[0].id
        sut.viewModel.currentPlayingIndex = 0

        // Act
        await sut.stopEntry()

        // Assert
        XCTAssertNil(sut.viewModel.playingEntryId)
        XCTAssertEqual(sut.viewModel.currentPlayingIndex, -1)
    }

    // MARK: - Helpers

    private func setupViewModelWithEntries(count: Int, audioAtIndices: [Int]? = nil) {
        var entries: [AudioEntryDTO] = []
        let indices = audioAtIndices ?? Array(0..<count)

        for i in 0..<count {
            let hasAudio = indices.contains(i)
            entries.append(AudioEntryDTO(
                id: UUID().uuidString,
                number: i + 1,
                textPreview: "Entry \(i + 1)...",
                audioPath: hasAudio ? "audio/entry_\(i + 1).wav" : nil,
                imagePath: nil,
                imageFullPath: nil
            ))
        }

        sut.viewModel.entries = entries
    }
}
