import XCTest
@testable import ReaderPro

/// Tests para el Value Object TimeRange
/// Representa un rango de tiempo para edición de audio
final class TimeRangeTests: XCTestCase {

    // MARK: - Creation Tests

    func test_createTimeRange_withValidValues_shouldSucceed() throws {
        // Arrange & Act
        let range = try TimeRange(start: 0.0, end: 10.0)

        // Assert
        XCTAssertEqual(range.start, 0.0)
        XCTAssertEqual(range.end, 10.0)
    }

    func test_createTimeRange_withStartZero_shouldSucceed() throws {
        // Arrange & Act
        let range = try TimeRange(start: 0.0, end: 5.0)

        // Assert
        XCTAssertEqual(range.start, 0.0)
        XCTAssertEqual(range.end, 5.0)
    }

    func test_createTimeRange_withNegativeStart_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try TimeRange(start: -1.0, end: 10.0)) { error in
            guard case DomainError.invalidTimeRange = error else {
                XCTFail("Expected DomainError.invalidTimeRange but got \(error)")
                return
            }
        }
    }

    func test_createTimeRange_withEndBeforeStart_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try TimeRange(start: 10.0, end: 5.0)) { error in
            guard case DomainError.invalidTimeRange = error else {
                XCTFail("Expected DomainError.invalidTimeRange but got \(error)")
                return
            }
        }
    }

    func test_createTimeRange_withEqualStartAndEnd_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try TimeRange(start: 5.0, end: 5.0)) { error in
            guard case DomainError.invalidTimeRange = error else {
                XCTFail("Expected DomainError.invalidTimeRange but got \(error)")
                return
            }
        }
    }

    // MARK: - Duration Tests

    func test_duration_shouldCalculateCorrectly() throws {
        // Arrange
        let range = try TimeRange(start: 2.0, end: 8.0)

        // Act
        let duration = range.duration

        // Assert
        XCTAssertEqual(duration, 6.0)
    }

    func test_duration_withZeroStart_shouldCalculateCorrectly() throws {
        // Arrange
        let range = try TimeRange(start: 0.0, end: 10.0)

        // Act
        let duration = range.duration

        // Assert
        XCTAssertEqual(duration, 10.0)
    }

    func test_duration_withDecimalValues_shouldCalculateCorrectly() throws {
        // Arrange
        let range = try TimeRange(start: 1.5, end: 3.7)

        // Act
        let duration = range.duration

        // Assert
        XCTAssertEqual(duration, 2.2, accuracy: 0.001)
    }

    // MARK: - Contains Tests

    func test_contains_withTimeInRange_shouldReturnTrue() throws {
        // Arrange
        let range = try TimeRange(start: 2.0, end: 8.0)

        // Act & Assert
        XCTAssertTrue(range.contains(5.0))
        XCTAssertTrue(range.contains(2.0))  // Inclusive start
        XCTAssertTrue(range.contains(8.0))  // Inclusive end
    }

    func test_contains_withTimeBeforeRange_shouldReturnFalse() throws {
        // Arrange
        let range = try TimeRange(start: 2.0, end: 8.0)

        // Act & Assert
        XCTAssertFalse(range.contains(1.5))
        XCTAssertFalse(range.contains(0.0))
    }

    func test_contains_withTimeAfterRange_shouldReturnFalse() throws {
        // Arrange
        let range = try TimeRange(start: 2.0, end: 8.0)

        // Act & Assert
        XCTAssertFalse(range.contains(8.5))
        XCTAssertFalse(range.contains(10.0))
    }

    // MARK: - Overlaps Tests

    func test_overlaps_withCompleteOverlap_shouldReturnTrue() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 4.0, end: 6.0)  // Completamente dentro

        // Act & Assert
        XCTAssertTrue(range1.overlaps(with: range2))
        XCTAssertTrue(range2.overlaps(with: range1))
    }

    func test_overlaps_withPartialOverlap_shouldReturnTrue() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 6.0, end: 10.0)  // Se solapan en 6-8

        // Act & Assert
        XCTAssertTrue(range1.overlaps(with: range2))
        XCTAssertTrue(range2.overlaps(with: range1))
    }

    func test_overlaps_withAdjacentRanges_shouldReturnFalse() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 5.0)
        let range2 = try TimeRange(start: 5.0, end: 8.0)  // Adyacentes en 5.0

        // Act & Assert
        // Nota: 5.0 está en ambos rangos (inclusive), así que SÍ se solapan
        XCTAssertTrue(range1.overlaps(with: range2))
    }

    func test_overlaps_withNonOverlappingRanges_shouldReturnFalse() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 5.0)
        let range2 = try TimeRange(start: 6.0, end: 10.0)  // No se tocan

        // Act & Assert
        XCTAssertFalse(range1.overlaps(with: range2))
        XCTAssertFalse(range2.overlaps(with: range1))
    }

    func test_overlaps_withStartAtEnd_shouldReturnTrue() throws {
        // Arrange
        let range1 = try TimeRange(start: 0.0, end: 5.0)
        let range2 = try TimeRange(start: 5.0, end: 10.0)

        // Act & Assert
        XCTAssertTrue(range1.overlaps(with: range2))
    }

    func test_overlaps_withIdenticalRanges_shouldReturnTrue() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 2.0, end: 8.0)

        // Act & Assert
        XCTAssertTrue(range1.overlaps(with: range2))
    }

    // MARK: - Equatable Tests

    func test_equality_withSameValues_shouldBeEqual() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 2.0, end: 8.0)

        // Assert
        XCTAssertEqual(range1, range2)
    }

    func test_equality_withDifferentStart_shouldNotBeEqual() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 3.0, end: 8.0)

        // Assert
        XCTAssertNotEqual(range1, range2)
    }

    func test_equality_withDifferentEnd_shouldNotBeEqual() throws {
        // Arrange
        let range1 = try TimeRange(start: 2.0, end: 8.0)
        let range2 = try TimeRange(start: 2.0, end: 9.0)

        // Assert
        XCTAssertNotEqual(range1, range2)
    }

    // MARK: - Edge Cases

    func test_createTimeRange_withVerySmallDuration_shouldSucceed() throws {
        // Arrange & Act
        let range = try TimeRange(start: 0.0, end: 0.001)

        // Assert
        XCTAssertEqual(range.duration, 0.001, accuracy: 0.0001)
    }

    func test_createTimeRange_withLargeDuration_shouldSucceed() throws {
        // Arrange & Act
        let range = try TimeRange(start: 0.0, end: 3600.0)  // 1 hora

        // Assert
        XCTAssertEqual(range.duration, 3600.0)
    }

    func test_contains_atBoundaries_shouldHandleCorrectly() throws {
        // Arrange
        let range = try TimeRange(start: 2.0, end: 8.0)

        // Act & Assert
        XCTAssertTrue(range.contains(2.0))   // Start boundary
        XCTAssertTrue(range.contains(8.0))   // End boundary
        XCTAssertFalse(range.contains(1.999))
        XCTAssertFalse(range.contains(8.001))
    }
}
