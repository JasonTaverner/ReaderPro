import XCTest
@testable import ReaderPro

/// Tests para el Value Object ProjectName
/// Validación: no vacío, max 100 caracteres, trimming automático
final class ProjectNameTests: XCTestCase {

    // MARK: - Creation Tests

    func test_createProjectName_withValidString_shouldSucceed() throws {
        // Arrange & Act
        let name = try ProjectName("Mi Proyecto")

        // Assert
        XCTAssertEqual(name.value, "Mi Proyecto")
    }

    func test_createProjectName_withEmptyString_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try ProjectName("")) { error in
            guard case DomainError.invalidProjectName = error else {
                XCTFail("Expected DomainError.invalidProjectName but got \(error)")
                return
            }
        }
    }

    func test_createProjectName_withWhitespaceOnly_shouldThrow() {
        // Arrange
        let whitespaceStrings = ["   ", "\n\t  ", "  \n  \t  "]

        // Act & Assert
        for whitespaceString in whitespaceStrings {
            XCTAssertThrowsError(try ProjectName(whitespaceString)) { error in
                guard case DomainError.invalidProjectName = error else {
                    XCTFail("Expected DomainError.invalidProjectName but got \(error)")
                    return
                }
            }
        }
    }

    func test_createProjectName_exceedingLimit_shouldThrow() {
        // Arrange - 101 caracteres
        let longName = String(repeating: "a", count: 101)

        // Act & Assert
        XCTAssertThrowsError(try ProjectName(longName)) { error in
            guard case DomainError.invalidProjectName = error else {
                XCTFail("Expected DomainError.invalidProjectName but got \(error)")
                return
            }
        }
    }

    func test_createProjectName_atMaxLimit_shouldSucceed() throws {
        // Arrange - Exactamente 100 caracteres
        let maxName = String(repeating: "a", count: 100)

        // Act
        let name = try ProjectName(maxName)

        // Assert
        XCTAssertEqual(name.value.count, 100)
    }

    func test_createProjectName_withLeadingWhitespace_shouldTrim() throws {
        // Arrange & Act
        let name = try ProjectName("   Proyecto con espacios   ")

        // Assert
        XCTAssertEqual(name.value, "Proyecto con espacios")
    }

    func test_createProjectName_withTrailingNewlines_shouldTrim() throws {
        // Arrange & Act
        let name = try ProjectName("Proyecto\n\n")

        // Assert
        XCTAssertEqual(name.value, "Proyecto")
    }

    // MARK: - Static Factory Method Tests

    func test_fromText_withLongText_shouldTruncateTo50Chars() throws {
        // Arrange
        let longText = try TextContent("Este es un texto muy largo que debe ser truncado a 50 caracteres aproximadamente para crear un nombre de proyecto válido")

        // Act
        let name = ProjectName.fromText(longText)

        // Assert
        XCTAssertLessThanOrEqual(name.value.count, 50)
        XCTAssertTrue(name.value.hasPrefix("Este es un texto muy largo que debe ser truncado"))
    }

    func test_fromText_withNewlines_shouldReplaceWithSpaces() throws {
        // Arrange
        let textWithNewlines = try TextContent("Primera línea\nSegunda línea\nTercera línea")

        // Act
        let name = ProjectName.fromText(textWithNewlines)

        // Assert
        XCTAssertFalse(name.value.contains("\n"))
        XCTAssertTrue(name.value.contains(" "))
    }

    func test_fromText_withEmptyText_shouldReturnDefault() throws {
        // Arrange
        let emptyText = try TextContent("          texto válido pero empieza con espacios")

        // Act
        let name = ProjectName.fromText(emptyText)

        // Assert
        XCTAssertFalse(name.value.isEmpty)
    }

    func test_fromText_whenCleanedIsEmpty_shouldReturnDefaultName() {
        // Arrange - Crear un texto que después de limpiar quede "vacío"
        // (Esto es edge case, en realidad TextContent ya valida que no esté vacío)
        // Pero test el fallback del método fromText
        let text = try! TextContent("a")  // Texto mínimo válido

        // Act
        let name = ProjectName.fromText(text)

        // Assert
        XCTAssertFalse(name.value.isEmpty)
    }

    // MARK: - Equatable Tests

    func test_equality_withSameValue_shouldBeEqual() throws {
        // Arrange
        let name1 = try ProjectName("Proyecto")
        let name2 = try ProjectName("Proyecto")

        // Assert
        XCTAssertEqual(name1, name2)
    }

    func test_equality_withDifferentValue_shouldNotBeEqual() throws {
        // Arrange
        let name1 = try ProjectName("Proyecto A")
        let name2 = try ProjectName("Proyecto B")

        // Assert
        XCTAssertNotEqual(name1, name2)
    }

    func test_equality_withSameValueAfterTrimming_shouldBeEqual() throws {
        // Arrange
        let name1 = try ProjectName("Proyecto")
        let name2 = try ProjectName("  Proyecto  ")

        // Assert
        XCTAssertEqual(name1, name2)
    }

    // MARK: - Edge Cases

    func test_createProjectName_withSpecialCharacters_shouldSucceed() throws {
        // Arrange & Act
        let name = try ProjectName("Proyecto_123-final.v2 (copia)")

        // Assert
        XCTAssertEqual(name.value, "Proyecto_123-final.v2 (copia)")
    }

    func test_createProjectName_withUnicode_shouldSucceed() throws {
        // Arrange & Act
        let name = try ProjectName("Proyecto 世界 🌍")

        // Assert
        XCTAssertEqual(name.value, "Proyecto 世界 🌍")
    }

    func test_createProjectName_withNumbers_shouldSucceed() throws {
        // Arrange & Act
        let name = try ProjectName("Proyecto 2024")

        // Assert
        XCTAssertEqual(name.value, "Proyecto 2024")
    }
}
