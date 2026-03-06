import Foundation
@testable import ReaderPro

/// Mock de ScreenCapturePort para testing
final class MockScreenCapturePort: ScreenCapturePort {

    // MARK: - Call Tracking

    var captureInteractiveCalled = false
    var captureCallCount = 0

    // MARK: - Stub Responses

    var capturedImageToReturn: CapturedImage?
    var errorToThrow: Error?
    var delayResponse = false

    // MARK: - Protocol Implementation

    func captureInteractive() async throws -> CapturedImage {
        captureInteractiveCalled = true
        captureCallCount += 1

        if delayResponse {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if let error = errorToThrow {
            throw error
        }

        guard let image = capturedImageToReturn else {
            return try CapturedImage(
                imageData: Data(repeating: 0xFF, count: 100),
                temporaryPath: "/tmp/mock_screenshot.png"
            )
        }

        return image
    }
}
