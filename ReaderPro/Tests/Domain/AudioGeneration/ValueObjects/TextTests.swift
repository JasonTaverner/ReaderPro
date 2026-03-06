import XCTest
@testable import ReaderPro

/// Tests para el Value Object TextContent
/// Validación: no vacío, max 6000 caracteres, cálculo de palabras y duración
final class TextTests: XCTestCase {

    // MARK: - Creation Tests

    func test_createText_withValidString_shouldSucceed() throws {
        // Arrange & Act
        let text = try TextContent("Hola mundo")

        // Assert
        XCTAssertEqual(text.value, "Hola mundo")
    }

    func test_createText_withEmptyString_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try TextContent("")) { error in
            guard case DomainError.invalidText = error else {
                XCTFail("Expected DomainError.invalidText but got \(error)")
                return
            }
        }
    }

    func test_createText_withWhitespaceOnly_shouldThrow() {
        // Arrange
        let whitespaceStrings = ["   ", "\n\t  ", "  \n  \t  "]

        // Act & Assert
        for whitespaceString in whitespaceStrings {
            XCTAssertThrowsError(try TextContent(whitespaceString)) { error in
                guard case DomainError.invalidText = error else {
                    XCTFail("Expected DomainError.invalidText for '\(whitespaceString)' but got \(error)")
                    return
                }
            }
        }
    }

    func test_createText_exceedingLimit_shouldThrow() {
        // Arrange - 6001 caracteres
        let longText = String(repeating: "a", count: 6001)

        // Act & Assert
        XCTAssertThrowsError(try TextContent(longText)) { error in
            guard case DomainError.invalidText = error else {
                XCTFail("Expected DomainError.invalidText but got \(error)")
                return
            }
        }
    }

    func test_createText_atMaxLimit_shouldSucceed() throws {
        // Arrange - Exactamente 6000 caracteres
        let maxText = String(repeating: "a", count: 6000)

        // Act
        let text = try TextContent(maxText)

        // Assert
        XCTAssertEqual(text.value.count, 6000)
    }

    // MARK: - Word Count Tests

    func test_wordCount_withSingleWord_shouldReturnOne() throws {
        // Arrange & Act
        let text = try TextContent("Hola")

        // Assert
        XCTAssertEqual(text.wordCount, 1)
    }

    func test_wordCount_withMultipleWords_shouldCalculateCorrectly() throws {
        // Arrange & Act
        let text = try TextContent("Uno dos tres cuatro cinco")

        // Assert
        XCTAssertEqual(text.wordCount, 5)
    }

    func test_wordCount_withExtraSpaces_shouldIgnoreThem() throws {
        // Arrange & Act
        let text = try TextContent("Uno  dos   tres")

        // Assert
        XCTAssertEqual(text.wordCount, 3)
    }

    func test_wordCount_withNewlines_shouldCount() throws {
        // Arrange & Act
        let text = try TextContent("Primera línea\nSegunda línea")

        // Assert
        XCTAssertEqual(text.wordCount, 4)
    }

    // MARK: - Estimated Duration Tests

    func test_estimatedDuration_with150Words_shouldReturn60Seconds() throws {
        // Arrange - 150 palabras (1 minuto a 150 wpm)
        let words = (1...150).map { "palabra\($0)" }.joined(separator: " ")
        let text = try TextContent(words)

        // Act
        let duration = text.estimatedDuration

        // Assert
        // 150 palabras / 150 wpm = 1 minuto = 60 segundos
        XCTAssertEqual(duration, 60.0, accuracy: 1.0)
    }

    func test_estimatedDuration_with75Words_shouldReturn30Seconds() throws {
        // Arrange - 75 palabras (0.5 minutos)
        let words = (1...75).map { "palabra\($0)" }.joined(separator: " ")
        let text = try TextContent(words)

        // Act
        let duration = text.estimatedDuration

        // Assert
        // 75 palabras / 150 wpm = 0.5 minutos = 30 segundos
        XCTAssertEqual(duration, 30.0, accuracy: 1.0)
    }

    func test_estimatedDuration_withFewWords_shouldReturnSmallDuration() throws {
        // Arrange
        let text = try TextContent("Hola mundo")

        // Act
        let duration = text.estimatedDuration

        // Assert
        // 2 palabras / 150 wpm = 0.0133 minutos = 0.8 segundos
        XCTAssertGreaterThan(duration, 0.0)
        XCTAssertLessThan(duration, 2.0)
    }

    // MARK: - Equatable Tests

    func test_equality_withSameValue_shouldBeEqual() throws {
        // Arrange
        let text1 = try TextContent("Mismo texto")
        let text2 = try TextContent("Mismo texto")

        // Assert
        XCTAssertEqual(text1, text2)
    }

    func test_equality_withDifferentValue_shouldNotBeEqual() throws {
        // Arrange
        let text1 = try TextContent("Texto uno")
        let text2 = try TextContent("Texto dos")

        // Assert
        XCTAssertNotEqual(text1, text2)
    }

    // MARK: - Edge Cases

    func test_createText_withUnicodeCharacters_shouldSucceed() throws {
        // Arrange & Act
        let text = try TextContent("Hola 世界 🌍 café")

        // Assert
        XCTAssertEqual(text.value, "Hola 世界 🌍 café")
        XCTAssertEqual(text.wordCount, 4)
    }

    func test_createText_withNumbers_shouldSucceed() throws {
        // Arrange & Act
        let text = try TextContent("123 456 789")

        // Assert
        XCTAssertEqual(text.wordCount, 3)
    }

    func test_createText_withPunctuation_shouldSucceed() throws {
        // Arrange & Act
        let text = try TextContent("Hola, ¿cómo estás? ¡Bien!")

        // Assert
        // Los signos de puntuación adheridos no se cuentan como palabras separadas
        XCTAssertGreaterThan(text.wordCount, 0)
    }
}
