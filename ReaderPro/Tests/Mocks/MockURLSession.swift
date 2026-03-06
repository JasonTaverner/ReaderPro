import Foundation
@testable import ReaderPro

/// Mock de URLSession para testing
final class MockURLSession: URLSessionProtocol {
    var lastRequest: URLRequest?
    var dataToReturn: Data = Data()
    var responseToReturn: URLResponse?
    var errorToThrow: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = errorToThrow {
            throw error
        }

        let response = responseToReturn ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (dataToReturn, response)
    }
}
