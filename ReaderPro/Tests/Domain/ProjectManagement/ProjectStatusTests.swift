import XCTest
@testable import ReaderPro

/// Tests para el Value Object ProjectStatus (enum)
/// Representa los estados posibles de un proyecto
final class ProjectStatusTests: XCTestCase {

    // MARK: - Enum Cases Tests

    func test_allCases_shouldContainExpectedStatuses() {
        // Act
        let allCases = ProjectStatus.allCases

        // Assert
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.draft))
        XCTAssertTrue(allCases.contains(.generating))
        XCTAssertTrue(allCases.contains(.ready))
        XCTAssertTrue(allCases.contains(.error))
    }

    // MARK: - RawValue Tests

    func test_draft_shouldHaveCorrectRawValue() {
        // Act
        let status = ProjectStatus.draft

        // Assert
        XCTAssertEqual(status.rawValue, "draft")
    }

    func test_generating_shouldHaveCorrectRawValue() {
        // Act
        let status = ProjectStatus.generating

        // Assert
        XCTAssertEqual(status.rawValue, "generating")
    }

    func test_ready_shouldHaveCorrectRawValue() {
        // Act
        let status = ProjectStatus.ready

        // Assert
        XCTAssertEqual(status.rawValue, "ready")
    }

    func test_error_shouldHaveCorrectRawValue() {
        // Act
        let status = ProjectStatus.error

        // Assert
        XCTAssertEqual(status.rawValue, "error")
    }

    // MARK: - Initialization from RawValue Tests

    func test_initWithRawValue_draft_shouldSucceed() {
        // Act
        let status = ProjectStatus(rawValue: "draft")

        // Assert
        XCTAssertEqual(status, .draft)
    }

    func test_initWithRawValue_generating_shouldSucceed() {
        // Act
        let status = ProjectStatus(rawValue: "generating")

        // Assert
        XCTAssertEqual(status, .generating)
    }

    func test_initWithRawValue_ready_shouldSucceed() {
        // Act
        let status = ProjectStatus(rawValue: "ready")

        // Assert
        XCTAssertEqual(status, .ready)
    }

    func test_initWithRawValue_error_shouldSucceed() {
        // Act
        let status = ProjectStatus(rawValue: "error")

        // Assert
        XCTAssertEqual(status, .error)
    }

    func test_initWithRawValue_invalid_shouldReturnNil() {
        // Act
        let status = ProjectStatus(rawValue: "invalid_status")

        // Assert
        XCTAssertNil(status)
    }

    // MARK: - Display Name Tests

    func test_displayName_draft_shouldReturnCorrectString() {
        // Act
        let displayName = ProjectStatus.draft.displayName

        // Assert
        XCTAssertEqual(displayName, "Borrador")
    }

    func test_displayName_generating_shouldReturnCorrectString() {
        // Act
        let displayName = ProjectStatus.generating.displayName

        // Assert
        XCTAssertEqual(displayName, "Generando...")
    }

    func test_displayName_ready_shouldReturnCorrectString() {
        // Act
        let displayName = ProjectStatus.ready.displayName

        // Assert
        XCTAssertEqual(displayName, "Listo")
    }

    func test_displayName_error_shouldReturnCorrectString() {
        // Act
        let displayName = ProjectStatus.error.displayName

        // Assert
        XCTAssertEqual(displayName, "Error")
    }

    // MARK: - Is Processing Tests

    func test_isProcessing_draft_shouldReturnFalse() {
        // Act
        let isProcessing = ProjectStatus.draft.isProcessing

        // Assert
        XCTAssertFalse(isProcessing)
    }

    func test_isProcessing_generating_shouldReturnTrue() {
        // Act
        let isProcessing = ProjectStatus.generating.isProcessing

        // Assert
        XCTAssertTrue(isProcessing)
    }

    func test_isProcessing_ready_shouldReturnFalse() {
        // Act
        let isProcessing = ProjectStatus.ready.isProcessing

        // Assert
        XCTAssertFalse(isProcessing)
    }

    func test_isProcessing_error_shouldReturnFalse() {
        // Act
        let isProcessing = ProjectStatus.error.isProcessing

        // Assert
        XCTAssertFalse(isProcessing)
    }

    // MARK: - Has Audio Tests

    func test_hasAudio_draft_shouldReturnFalse() {
        // Act
        let hasAudio = ProjectStatus.draft.hasAudio

        // Assert
        XCTAssertFalse(hasAudio)
    }

    func test_hasAudio_generating_shouldReturnFalse() {
        // Act
        let hasAudio = ProjectStatus.generating.hasAudio

        // Assert
        XCTAssertFalse(hasAudio)
    }

    func test_hasAudio_ready_shouldReturnTrue() {
        // Act
        let hasAudio = ProjectStatus.ready.hasAudio

        // Assert
        XCTAssertTrue(hasAudio)
    }

    func test_hasAudio_error_shouldReturnFalse() {
        // Act
        let hasAudio = ProjectStatus.error.hasAudio

        // Assert
        XCTAssertFalse(hasAudio)
    }

    // MARK: - Can Regenerate Tests

    func test_canRegenerate_draft_shouldReturnTrue() {
        // Act
        let canRegenerate = ProjectStatus.draft.canRegenerate

        // Assert
        XCTAssertTrue(canRegenerate)
    }

    func test_canRegenerate_generating_shouldReturnFalse() {
        // Act
        let canRegenerate = ProjectStatus.generating.canRegenerate

        // Assert
        XCTAssertFalse(canRegenerate)
    }

    func test_canRegenerate_ready_shouldReturnTrue() {
        // Act
        let canRegenerate = ProjectStatus.ready.canRegenerate

        // Assert
        XCTAssertTrue(canRegenerate)
    }

    func test_canRegenerate_error_shouldReturnTrue() {
        // Act
        let canRegenerate = ProjectStatus.error.canRegenerate

        // Assert
        XCTAssertTrue(canRegenerate)
    }

    // MARK: - Equatable Tests

    func test_equality_sameStatus_shouldBeEqual() {
        // Arrange
        let status1 = ProjectStatus.draft
        let status2 = ProjectStatus.draft

        // Assert
        XCTAssertEqual(status1, status2)
    }

    func test_equality_differentStatus_shouldNotBeEqual() {
        // Arrange
        let status1 = ProjectStatus.draft
        let status2 = ProjectStatus.ready

        // Assert
        XCTAssertNotEqual(status1, status2)
    }

    // MARK: - Practical Usage Tests

    func test_statusTransition_draftToGenerating() {
        // Arrange
        var status = ProjectStatus.draft

        // Act
        status = .generating

        // Assert
        XCTAssertEqual(status, .generating)
        XCTAssertTrue(status.isProcessing)
    }

    func test_statusTransition_generatingToReady() {
        // Arrange
        var status = ProjectStatus.generating

        // Act
        status = .ready

        // Assert
        XCTAssertEqual(status, .ready)
        XCTAssertTrue(status.hasAudio)
        XCTAssertFalse(status.isProcessing)
    }

    func test_statusTransition_generatingToError() {
        // Arrange
        var status = ProjectStatus.generating

        // Act
        status = .error

        // Assert
        XCTAssertEqual(status, .error)
        XCTAssertTrue(status.canRegenerate)
    }

    func test_statusArray_canBeSorted() {
        // Arrange
        let statuses: [ProjectStatus] = [.error, .ready, .draft, .generating]

        // Act - Ordenar por rawValue
        let sorted = statuses.sorted { $0.rawValue < $1.rawValue }

        // Assert
        XCTAssertEqual(sorted[0], .draft)
        XCTAssertEqual(sorted[1], .error)
        XCTAssertEqual(sorted[2], .generating)
        XCTAssertEqual(sorted[3], .ready)
    }

    func test_statusFilter_onlyProcessing() {
        // Arrange
        let statuses: [ProjectStatus] = [.draft, .generating, .ready, .error]

        // Act
        let processing = statuses.filter { $0.isProcessing }

        // Assert
        XCTAssertEqual(processing.count, 1)
        XCTAssertEqual(processing.first, .generating)
    }

    func test_statusFilter_withAudio() {
        // Arrange
        let statuses: [ProjectStatus] = [.draft, .generating, .ready, .error]

        // Act
        let withAudio = statuses.filter { $0.hasAudio }

        // Assert
        XCTAssertEqual(withAudio.count, 1)
        XCTAssertEqual(withAudio.first, .ready)
    }

    func test_statusFilter_canRegenerate() {
        // Arrange
        let statuses: [ProjectStatus] = [.draft, .generating, .ready, .error]

        // Act
        let canRegenerate = statuses.filter { $0.canRegenerate }

        // Assert
        XCTAssertEqual(canRegenerate.count, 3)
        XCTAssertTrue(canRegenerate.contains(.draft))
        XCTAssertTrue(canRegenerate.contains(.ready))
        XCTAssertTrue(canRegenerate.contains(.error))
    }
}
