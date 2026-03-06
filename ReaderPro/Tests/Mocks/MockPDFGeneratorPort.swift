import Foundation
@testable import ReaderPro

final class MockPDFGeneratorPort: PDFGeneratorPort {

    // MARK: - Call Tracking

    var generatePDFCallCount = 0

    // MARK: - Captured Arguments

    var lastImagePaths: [String]?
    var lastOutputPath: String?

    // MARK: - Stubbed Returns

    var generatePDFResult: String = "/exports/documento.pdf"

    // MARK: - Error Injection

    var errorToThrow: Error?

    // MARK: - PDFGeneratorPort Implementation

    func generatePDF(from imagePaths: [String], outputPath: String) async throws -> String {
        generatePDFCallCount += 1
        lastImagePaths = imagePaths
        lastOutputPath = outputPath
        if let error = errorToThrow { throw error }
        return generatePDFResult
    }
}
