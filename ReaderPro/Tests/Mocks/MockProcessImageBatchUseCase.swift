import Foundation
@testable import ReaderPro

/// Mock de ProcessImageBatchUseCase para testing
@MainActor
final class MockProcessImageBatchUseCase: ProcessImageBatchUseCaseProtocol {

    // MARK: - Call Tracking

    var executeCalled = false
    var executeCallCount = 0
    var lastRequest: ProcessImageBatchRequest?

    // MARK: - Stub Responses

    var responseToReturn: ProcessImageBatchResponse?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - Protocol Implementation

    func execute(_ request: ProcessImageBatchRequest) async throws -> ProcessImageBatchResponse {
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
            return ProcessImageBatchResponse(
                successfulEntries: [],
                failedImages: [],
                totalImages: 0
            )
        }

        return response
    }
}
