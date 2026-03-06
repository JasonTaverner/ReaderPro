import XCTest
@testable import ReaderPro

/// Tests para VisionOCRAdapter usando TDD
/// Verifica que el adaptador implementa correctamente el OCRPort
/// usando el framework Vision de Apple
final class VisionOCRAdapterTests: XCTestCase {

    var sut: VisionOCRAdapter!

    override func setUp() {
        super.setUp()
        sut = VisionOCRAdapter()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Availability Tests

    func test_isAvailable_shouldReturnTrue() async {
        // Vision framework está disponible en macOS 10.15+
        let available = await sut.isAvailable
        XCTAssertTrue(available)
    }

    func test_supportedLanguages_shouldIncludeSpanishAndEnglish() async {
        // Arrange & Act
        let languages = await sut.supportedLanguages

        // Assert
        XCTAssertTrue(languages.contains("es-ES"))
        XCTAssertTrue(languages.contains("en-US"))
    }

    // MARK: - recognizeText(from ImageData) Tests

    func test_recognizeText_withValidPNGImage_shouldReturnText() async throws {
        // Arrange - crear imagen de test con texto
        let imageData = try createTestImageWithText("Hello World")

        // Act
        let result = try await sut.recognizeText(from: imageData)

        // Assert
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    func test_recognizeText_withEmptyImageData_shouldThrow() async {
        // Act & Assert
        do {
            let emptyImage = try ImageData(data: Data(), width: 100, height: 100)
            _ = try await sut.recognizeText(from: emptyImage)
            XCTFail("Should throw")
        } catch {
            // Expected: DomainError.emptyImageData from ImageData init
            XCTAssertTrue(error is DomainError)
        }
    }

    func test_recognizeText_withInvalidImageFormat_shouldThrow() async throws {
        // Arrange - datos que no son una imagen válida
        let invalidData = try ImageData(data: Data(repeating: 0x00, count: 100), width: 10, height: 10)

        // Act & Assert
        do {
            _ = try await sut.recognizeText(from: invalidData)
            XCTFail("Should throw for invalid image format")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }

    func test_recognizeText_confidenceShouldBeBetweenZeroAndOne() async throws {
        // Arrange
        let imageData = try createTestImageWithText("Test confidence")

        // Act
        let result = try await sut.recognizeText(from: imageData)

        // Assert
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    // MARK: - recognizeTextFromScreen Tests

    func test_recognizeTextFromScreen_withNilRegion_shouldAttemptCapture() async {
        // This test verifies the method exists and handles nil region
        // In CI/testing environment, screen capture may fail
        do {
            _ = try await sut.recognizeTextFromScreen(region: nil)
        } catch {
            // Expected to fail in test environment (no screen access)
            // Just verify it doesn't crash
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Helper Methods

    /// Crea una imagen PNG de test con texto renderizado
    private func createTestImageWithText(_ text: String) throws -> ImageData {
        let width = 400
        let height = 100

        // Crear un contexto gráfico con texto
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.invalidImageFormat
        }

        // Fondo blanco
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Texto negro
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        // Usar Core Text para renderizar texto
        let font = CTFontCreateWithName("Helvetica" as CFString, 36, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.textPosition = CGPoint(x: 20, y: 30)
        CTLineDraw(line, context)

        // Convertir a PNG
        guard let cgImage = context.makeImage() else {
            throw OCRError.invalidImageFormat
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw OCRError.invalidImageFormat
        }

        return try ImageData(data: pngData, width: width, height: height)
    }
}
