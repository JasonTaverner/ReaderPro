import XCTest
@testable import ReaderPro

/// Tests para la Entity AudioSegment
/// Representa un segmento de audio editado con su rango temporal
final class AudioSegmentTests: XCTestCase {

    // MARK: - Type Alias

    typealias SegmentId = Identifier<AudioSegment>

    // MARK: - Helpers

    private func makeValidText() -> TextContent {
        try! TextContent("Texto del segmento")
    }

    private func makeValidTimeRange() -> TimeRange {
        try! TimeRange(start: 0.0, end: 10.0)
    }

    // MARK: - Creation Tests

    func test_createAudioSegment_withTextAndTimeRange_shouldSucceed() throws {
        // Arrange
        let text = makeValidText()
        let timeRange = makeValidTimeRange()

        // Act
        let segment = AudioSegment(text: text, timeRange: timeRange)

        // Assert
        XCTAssertNotNil(segment.id)
        XCTAssertEqual(segment.text, text)
        XCTAssertEqual(segment.timeRange, timeRange)
        XCTAssertNil(segment.audioPath)
    }

    func test_createAudioSegment_withAudioPath_shouldSucceed() throws {
        // Arrange
        let text = makeValidText()
        let timeRange = makeValidTimeRange()
        let audioPath = "/path/to/segment.wav"

        // Act
        let segment = AudioSegment(text: text, timeRange: timeRange, audioPath: audioPath)

        // Assert
        XCTAssertEqual(segment.audioPath, audioPath)
    }

    func test_createAudioSegment_shouldGenerateUniqueId() throws {
        // Arrange
        let text = makeValidText()
        let timeRange = makeValidTimeRange()

        // Act
        let segment1 = AudioSegment(text: text, timeRange: timeRange)
        let segment2 = AudioSegment(text: text, timeRange: timeRange)

        // Assert
        XCTAssertNotEqual(segment1.id, segment2.id)
    }

    // MARK: - Reconstitution Tests

    func test_createAudioSegment_withExistingId_shouldUseProvidedId() throws {
        // Arrange
        let id = SegmentId()
        let text = makeValidText()
        let timeRange = makeValidTimeRange()

        // Act
        let segment = AudioSegment(
            id: id,
            text: text,
            timeRange: timeRange,
            audioPath: "/audio.wav"
        )

        // Assert
        XCTAssertEqual(segment.id, id)
    }

    // MARK: - Mutability Tests

    func test_setAudioPath_shouldUpdatePath() throws {
        // Arrange
        var segment = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange())
        XCTAssertNil(segment.audioPath)

        // Act
        segment.setAudioPath("/new/segment.wav")

        // Assert
        XCTAssertEqual(segment.audioPath, "/new/segment.wav")
    }

    // MARK: - Duration Tests

    func test_duration_shouldMatchTimeRangeDuration() throws {
        // Arrange
        let timeRange = try TimeRange(start: 2.0, end: 8.0)  // 6 segundos
        let segment = AudioSegment(text: makeValidText(), timeRange: timeRange)

        // Act
        let duration = segment.duration

        // Assert
        XCTAssertEqual(duration, 6.0)
    }

    func test_duration_withDifferentRanges() throws {
        // Arrange & Act
        let segment1 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 5.0))
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 15.5))
        let segment3 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 60.0))

        // Assert
        XCTAssertEqual(segment1.duration, 5.0)
        XCTAssertEqual(segment2.duration, 5.5)
        XCTAssertEqual(segment3.duration, 60.0)
    }

    // MARK: - Has Audio Tests

    func test_hasAudio_withNoAudioPath_shouldReturnFalse() throws {
        // Arrange
        let segment = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange())

        // Assert
        XCTAssertFalse(segment.hasAudio)
    }

    func test_hasAudio_withAudioPath_shouldReturnTrue() throws {
        // Arrange
        let segment = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange(), audioPath: "/audio.wav")

        // Assert
        XCTAssertTrue(segment.hasAudio)
    }

    // MARK: - Contains Time Tests

    func test_containsTime_whenTimeIsInRange_shouldReturnTrue() throws {
        // Arrange
        let timeRange = try TimeRange(start: 5.0, end: 15.0)
        let segment = AudioSegment(text: makeValidText(), timeRange: timeRange)

        // Act & Assert
        XCTAssertTrue(segment.containsTime(10.0))
        XCTAssertTrue(segment.containsTime(5.0))   // Boundary
        XCTAssertTrue(segment.containsTime(15.0))  // Boundary
    }

    func test_containsTime_whenTimeIsOutOfRange_shouldReturnFalse() throws {
        // Arrange
        let timeRange = try TimeRange(start: 5.0, end: 15.0)
        let segment = AudioSegment(text: makeValidText(), timeRange: timeRange)

        // Act & Assert
        XCTAssertFalse(segment.containsTime(4.9))
        XCTAssertFalse(segment.containsTime(15.1))
        XCTAssertFalse(segment.containsTime(0.0))
        XCTAssertFalse(segment.containsTime(100.0))
    }

    // MARK: - Overlaps Tests

    func test_overlaps_whenSegmentsOverlap_shouldReturnTrue() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 5.0, end: 15.0))
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 20.0))

        // Act & Assert
        XCTAssertTrue(segment1.overlaps(with: segment2))
        XCTAssertTrue(segment2.overlaps(with: segment1))
    }

    func test_overlaps_whenSegmentsDoNotOverlap_shouldReturnFalse() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 5.0))
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 15.0))

        // Act & Assert
        XCTAssertFalse(segment1.overlaps(with: segment2))
        XCTAssertFalse(segment2.overlaps(with: segment1))
    }

    func test_overlaps_whenSegmentsAreAdjacent_shouldHandleCorrectly() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 5.0))
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 5.0, end: 10.0))

        // Act & Assert - TimeRange considera 5.0 en ambos rangos (inclusive)
        XCTAssertTrue(segment1.overlaps(with: segment2))
    }

    // MARK: - Equatable Tests (por ID)

    func test_equality_withSameId_shouldBeEqual() throws {
        // Arrange
        let id = SegmentId()
        let text1 = try TextContent("Texto 1")
        let text2 = try TextContent("Texto 2")
        let timeRange1 = try TimeRange(start: 0.0, end: 5.0)
        let timeRange2 = try TimeRange(start: 5.0, end: 10.0)

        let segment1 = AudioSegment(id: id, text: text1, timeRange: timeRange1, audioPath: nil)
        let segment2 = AudioSegment(id: id, text: text2, timeRange: timeRange2, audioPath: "/different.wav")

        // Assert - Mismo ID = misma entity
        XCTAssertEqual(segment1, segment2)
    }

    func test_equality_withDifferentId_shouldNotBeEqual() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange())
        let segment2 = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange())

        // Assert
        XCTAssertNotEqual(segment1, segment2)
    }

    // MARK: - Hashable Tests

    func test_hashable_canBeUsedInSet() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: makeValidTimeRange())
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 20.0))
        let segment3 = AudioSegment(id: segment1.id, text: makeValidText(), timeRange: makeValidTimeRange(), audioPath: nil)

        // Act
        var segmentSet: Set<AudioSegment> = []
        segmentSet.insert(segment1)
        segmentSet.insert(segment2)
        segmentSet.insert(segment3)  // Mismo ID que segment1

        // Assert
        XCTAssertEqual(segmentSet.count, 2)
    }

    // MARK: - Practical Usage Tests

    func test_segments_canBeStoredInArray() throws {
        // Arrange
        let segments = [
            AudioSegment(text: try TextContent("Segmento 1"), timeRange: try TimeRange(start: 0.0, end: 5.0)),
            AudioSegment(text: try TextContent("Segmento 2"), timeRange: try TimeRange(start: 5.0, end: 10.0)),
            AudioSegment(text: try TextContent("Segmento 3"), timeRange: try TimeRange(start: 10.0, end: 15.0))
        ]

        // Assert
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].duration, 5.0)
        XCTAssertEqual(segments[1].duration, 5.0)
        XCTAssertEqual(segments[2].duration, 5.0)
    }

    func test_segments_canBeSortedByTimeRange() throws {
        // Arrange
        let segments = [
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 15.0)),
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 5.0)),
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 5.0, end: 10.0))
        ]

        // Act
        let sorted = segments.sorted { $0.timeRange.start < $1.timeRange.start }

        // Assert
        XCTAssertEqual(sorted[0].timeRange.start, 0.0)
        XCTAssertEqual(sorted[1].timeRange.start, 5.0)
        XCTAssertEqual(sorted[2].timeRange.start, 10.0)
    }

    func test_segments_canBeFilteredByHasAudio() throws {
        // Arrange
        let segments = [
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 5.0), audioPath: "/audio1.wav"),
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 5.0, end: 10.0)),
            AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 10.0, end: 15.0), audioPath: "/audio2.wav")
        ]

        // Act
        let withAudio = segments.filter { $0.hasAudio }

        // Assert
        XCTAssertEqual(withAudio.count, 2)
    }

    func test_segments_detectOverlaps() throws {
        // Arrange
        let segment1 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 0.0, end: 10.0))
        let segment2 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 5.0, end: 15.0))
        let segment3 = AudioSegment(text: makeValidText(), timeRange: try TimeRange(start: 20.0, end: 30.0))

        // Act & Assert
        XCTAssertTrue(segment1.overlaps(with: segment2))   // Overlap
        XCTAssertFalse(segment1.overlaps(with: segment3))  // No overlap
        XCTAssertFalse(segment2.overlaps(with: segment3))  // No overlap
    }

    // MARK: - Edge Cases

    func test_segment_withVerySmallDuration_shouldWork() throws {
        // Arrange
        let timeRange = try TimeRange(start: 0.0, end: 0.001)  // 1 milisegundo
        let segment = AudioSegment(text: makeValidText(), timeRange: timeRange)

        // Assert
        XCTAssertEqual(segment.duration, 0.001, accuracy: 0.0001)
    }

    func test_segment_withLargeDuration_shouldWork() throws {
        // Arrange
        let timeRange = try TimeRange(start: 0.0, end: 3600.0)  // 1 hora
        let segment = AudioSegment(text: makeValidText(), timeRange: timeRange)

        // Assert
        XCTAssertEqual(segment.duration, 3600.0)
    }
}
