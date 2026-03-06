import Foundation
@testable import ReaderPro

/// Mock de CaptureAndProcessUseCase para testing
final class MockCaptureAndProcessUseCase: CaptureAndProcessUseCaseProtocol {

    // MARK: - Call Tracking

    var executeCalled = false
    var executeCallCount = 0
    var lastRequest: CaptureAndProcessRequest?

    // MARK: - Stub Responses

    var responseToReturn: CaptureAndProcessResponse?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - Protocol Implementation

    func execute(_ request: CaptureAndProcessRequest) async throws -> CaptureAndProcessResponse {
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
            return CaptureAndProcessResponse(
                recognizedText: "Default mock text",
                confidence: 0.95,
                entryId: "001",
                entryNumber: 1,
                imagePath: "/tmp/mock.png",
                audioPath: nil
            )
        }

        return response
    }
}
