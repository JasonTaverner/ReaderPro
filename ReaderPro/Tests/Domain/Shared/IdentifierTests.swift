import XCTest
@testable import ReaderPro

/// Tests para el Value Object genérico Identifier<T>
/// Proporciona type-safe IDs para Entities
final class IdentifierTests: XCTestCase {

    // MARK: - Type Definitions for Testing

    // Tipos dummy para tests
    struct DummyProject {}
    struct DummyAudioEntry {}
    struct DummyVoice {}

    // MARK: - Creation Tests

    func test_createIdentifier_withDefaultInit_shouldGenerateUUID() {
        // Act
        let id = Identifier<DummyProject>()

        // Assert
        XCTAssertNotNil(id.value)
        XCTAssertFalse(id.value.uuidString.isEmpty)
    }

    func test_createIdentifier_withUUID_shouldStoreValue() {
        // Arrange
        let uuid = UUID()

        // Act
        let id = Identifier<DummyProject>(uuid)

        // Assert
        XCTAssertEqual(id.value, uuid)
    }

    func test_createIdentifier_multipleInvocations_shouldGenerateUniqueIds() {
        // Act
        let id1 = Identifier<DummyProject>()
        let id2 = Identifier<DummyProject>()
        let id3 = Identifier<DummyProject>()

        // Assert
        XCTAssertNotEqual(id1.value, id2.value)
        XCTAssertNotEqual(id2.value, id3.value)
        XCTAssertNotEqual(id1.value, id3.value)
    }

    // MARK: - Type Safety Tests

    func test_identifiers_withDifferentTypes_shouldNotBeComparable() {
        // Arrange
        let projectId = Identifier<DummyProject>()
        let entryId = Identifier<DummyAudioEntry>()

        // Assert - Esto debe compilar porque son tipos diferentes
        // No pueden ser comparados directamente (type safety)
        XCTAssertNotEqual(projectId.value, entryId.value)
    }

    func test_identifiers_sameTypeDifferentValues_shouldNotBeEqual() {
        // Arrange
        let id1 = Identifier<DummyProject>()
        let id2 = Identifier<DummyProject>()

        // Assert
        XCTAssertNotEqual(id1, id2)
    }

    func test_identifiers_sameTypeSameValue_shouldBeEqual() {
        // Arrange
        let uuid = UUID()
        let id1 = Identifier<DummyProject>(uuid)
        let id2 = Identifier<DummyProject>(uuid)

        // Assert
        XCTAssertEqual(id1, id2)
    }

    // MARK: - Equatable Tests

    func test_equality_withSameUUID_shouldBeEqual() {
        // Arrange
        let uuid = UUID()
        let id1 = Identifier<DummyProject>(uuid)
        let id2 = Identifier<DummyProject>(uuid)

        // Assert
        XCTAssertEqual(id1, id2)
    }

    func test_equality_withDifferentUUID_shouldNotBeEqual() {
        // Arrange
        let id1 = Identifier<DummyProject>(UUID())
        let id2 = Identifier<DummyProject>(UUID())

        // Assert
        XCTAssertNotEqual(id1, id2)
    }

    // MARK: - Hashable Tests

    func test_hashable_shouldBeUsableInSet() {
        // Arrange
        let id1 = Identifier<DummyProject>()
        let id2 = Identifier<DummyProject>()
        let id3 = Identifier<DummyProject>()

        // Act
        var idSet: Set<Identifier<DummyProject>> = []
        idSet.insert(id1)
        idSet.insert(id2)
        idSet.insert(id3)
        idSet.insert(id1)  // Duplicado

        // Assert
        XCTAssertEqual(idSet.count, 3)  // Solo 3 únicos
        XCTAssertTrue(idSet.contains(id1))
        XCTAssertTrue(idSet.contains(id2))
        XCTAssertTrue(idSet.contains(id3))
    }

    func test_hashable_shouldBeUsableInDictionary() {
        // Arrange
        let id1 = Identifier<DummyProject>()
        let id2 = Identifier<DummyProject>()

        // Act
        var dict: [Identifier<DummyProject>: String] = [:]
        dict[id1] = "Project 1"
        dict[id2] = "Project 2"

        // Assert
        XCTAssertEqual(dict[id1], "Project 1")
        XCTAssertEqual(dict[id2], "Project 2")
        XCTAssertEqual(dict.count, 2)
    }

    // MARK: - CustomStringConvertible Tests

    func test_description_shouldReturnUUIDString() {
        // Arrange
        let uuid = UUID()
        let id = Identifier<DummyProject>(uuid)

        // Act
        let description = id.description

        // Assert
        XCTAssertEqual(description, uuid.uuidString)
    }

    // MARK: - Practical Usage Tests

    func test_practicalUsage_asProjectId() {
        // Arrange
        typealias ProjectId = Identifier<DummyProject>

        // Act
        let projectId = ProjectId()

        // Assert
        XCTAssertFalse(projectId.value.uuidString.isEmpty)
    }

    func test_practicalUsage_asEntryId() {
        // Arrange
        typealias EntryId = Identifier<DummyAudioEntry>

        // Act
        let entryId = EntryId()

        // Assert
        XCTAssertFalse(entryId.value.uuidString.isEmpty)
    }

    func test_practicalUsage_storageInArray() {
        // Arrange
        typealias ProjectId = Identifier<DummyProject>
        let ids = [ProjectId(), ProjectId(), ProjectId()]

        // Act
        let uniqueIds = Set(ids)

        // Assert
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(uniqueIds.count, 3)
    }

    // MARK: - Edge Cases

    func test_identifiers_withZeroUUID_shouldWork() {
        // Arrange - UUID con todos ceros (válido pero poco común)
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let id = Identifier<DummyProject>(zeroUUID)

        // Assert
        XCTAssertEqual(id.value, zeroUUID)
    }

    func test_identifiers_createdRapidly_shouldAllBeUnique() {
        // Act - Crear muchos IDs rápidamente
        let ids = (0..<1000).map { _ in Identifier<DummyProject>() }

        // Assert - Todos deben ser únicos
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 1000)
    }
}
