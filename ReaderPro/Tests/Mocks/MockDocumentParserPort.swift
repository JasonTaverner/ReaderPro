import Foundation
@testable import ReaderPro

/// Mock de DocumentParserPort para testing
@MainActor
final class MockDocumentParserPort: DocumentParserPort {

    // MARK: - Call Tracking

    var extractSectionsCalled = false
    var extractSectionsCallCount = 0
    var lastURL: URL?

    // MARK: - Stub Responses

    var sectionsToReturn: [DocumentSection]?
    var errorToThrow: Error?

    // MARK: - Protocol Properties

    var supportedExtensions: [String] = []

    // MARK: - Protocol Implementation

    func extractSections(from url: URL) async throws -> [DocumentSection] {
        extractSectionsCalled = true
        extractSectionsCallCount += 1
        lastURL = url

        if let error = errorToThrow {
            throw error
        }

        return sectionsToReturn ?? []
    }
}
