import Foundation
@testable import ReaderPro

/// Mock de ProcessDocumentUseCase para testing
@MainActor
final class MockProcessDocumentUseCase: ProcessDocumentUseCaseProtocol {

    // MARK: - Call Tracking

    var executeCalled = false
    var executeCallCount = 0
    var lastRequest: ProcessDocumentRequest?

    // MARK: - Stub Responses

    var responseToReturn: ProcessDocumentResponse?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - Protocol Implementation

    func execute(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse {
        executeCalled = true
        executeCallCount += 1
        lastRequest = request

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if let error = errorToThrow {
            throw error
        }

        guard let response = responseToReturn else {
            return ProcessDocumentResponse(
                successfulEntries: [],
                failedSections: [],
                totalSections: 0,
                documentType: ""
            )
        }

        return response
    }
}
