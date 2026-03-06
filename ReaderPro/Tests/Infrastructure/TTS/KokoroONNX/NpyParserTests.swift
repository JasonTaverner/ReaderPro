import XCTest
@testable import ReaderPro

final class NpyParserTests: XCTestCase {

    // MARK: - Valid .npy Parsing

    func test_parse_validNpyV1_shouldReturnCorrectShape() throws {
        // Arrange - Create a valid v1 .npy with shape (2, 3) float32
        let data = makeNpyV1(shape: [2, 3], floats: [1, 2, 3, 4, 5, 6])

        // Act
        let result = try NpyParser.parse(data)

        // Assert
        XCTAssertEqual(result.shape, [2, 3])
        XCTAssertEqual(result.data.count, 6)
        XCTAssertEqual(result.data, [1, 2, 3, 4, 5, 6])
    }

    func test_parse_validNpyV1_singleElement_shouldWork() throws {
        // Arrange
        let data = makeNpyV1(shape: [1], floats: [42.5])

        // Act
        let result = try NpyParser.parse(data)

        // Assert
        XCTAssertEqual(result.shape, [1])
        XCTAssertEqual(result.data, [42.5])
    }

    func test_parse_validNpyV1_3dShape_shouldWork() throws {
        // Arrange - shape (2, 1, 3) = 6 elements
        let floats: [Float32] = [1, 2, 3, 4, 5, 6]
        let data = makeNpyV1(shape: [2, 1, 3], floats: floats)

        // Act
        let result = try NpyParser.parse(data)

        // Assert
        XCTAssertEqual(result.shape, [2, 1, 3])
        XCTAssertEqual(result.data, floats)
    }

    // MARK: - Invalid Magic

    func test_parse_invalidMagic_shouldThrow() {
        // Arrange
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parse(data)) { error in
            guard case NpyParser.NpyError.invalidMagic = error else {
                XCTFail("Expected invalidMagic, got \(error)")
                return
            }
        }
    }

    func test_parse_tooShort_shouldThrow() {
        // Arrange
        let data = Data([0x93, 0x4E, 0x55])

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parse(data)) { error in
            guard case NpyParser.NpyError.invalidMagic = error else {
                XCTFail("Expected invalidMagic, got \(error)")
                return
            }
        }
    }

    // MARK: - Unsupported Version

    func test_parse_unsupportedVersion_shouldThrow() {
        // Arrange - version 3.0
        var data = Data([0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59]) // magic
        data.append(contentsOf: [3, 0]) // version 3.0
        data.append(contentsOf: [0, 0, 0, 0]) // padding
        data.append(contentsOf: [0, 0]) // more padding

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parse(data)) { error in
            guard case NpyParser.NpyError.unsupportedVersion(let major, _) = error else {
                XCTFail("Expected unsupportedVersion, got \(error)")
                return
            }
            XCTAssertEqual(major, 3)
        }
    }

    // MARK: - Data Size Mismatch

    func test_parse_dataSizeMismatch_shouldThrow() throws {
        // Arrange - header says shape (10,) but only 2 floats of data
        let data = makeNpyV1(shape: [10], floats: [1, 2])

        // Act & Assert - The file will be truncated because we write fewer floats than the shape demands
        // We need to construct this manually with mismatched data
        let badData = makeNpyV1Raw(shapeStr: "10,", floatBytes: 2 * 4) // only 2 floats, claims 10

        XCTAssertThrowsError(try NpyParser.parse(badData)) { error in
            guard case NpyParser.NpyError.dataSizeMismatch = error else {
                XCTFail("Expected dataSizeMismatch, got \(error)")
                return
            }
        }
    }

    // MARK: - Header Parsing

    func test_parseHeader_standardFloat32_shouldWork() throws {
        // Arrange
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': (510, 1, 256), }"

        // Act
        let (dtype, shape) = try NpyParser.parseHeader(header)

        // Assert
        XCTAssertEqual(dtype, "<f4")
        XCTAssertEqual(shape, [510, 1, 256])
    }

    func test_parseHeader_1dShape_shouldWork() throws {
        // Arrange
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': (100,), }"

        // Act
        let (dtype, shape) = try NpyParser.parseHeader(header)

        // Assert
        XCTAssertEqual(dtype, "<f4")
        XCTAssertEqual(shape, [100])
    }

    func test_parseHeader_missingDescr_shouldThrow() {
        // Arrange
        let header = "{'fortran_order': False, 'shape': (10,), }"

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parseHeader(header)) { error in
            guard case NpyParser.NpyError.headerParseFailed = error else {
                XCTFail("Expected headerParseFailed, got \(error)")
                return
            }
        }
    }

    func test_parseHeader_missingShape_shouldThrow() {
        // Arrange
        let header = "{'descr': '<f4', 'fortran_order': False, }"

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parseHeader(header)) { error in
            guard case NpyParser.NpyError.headerParseFailed = error else {
                XCTFail("Expected headerParseFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Unsupported Dtype

    func test_parse_int32Dtype_shouldThrow() throws {
        // Arrange
        let data = makeNpyV1Raw(dtype: "<i4", shapeStr: "2,", floatBytes: 8)

        // Act & Assert
        XCTAssertThrowsError(try NpyParser.parse(data)) { error in
            guard case NpyParser.NpyError.unsupportedDtype(let dtype) = error else {
                XCTFail("Expected unsupportedDtype, got \(error)")
                return
            }
            XCTAssertEqual(dtype, "<i4")
        }
    }

    // MARK: - Version 2

    func test_parse_validNpyV2_shouldWork() throws {
        // Arrange
        let data = makeNpyV2(shape: [3], floats: [1.0, 2.0, 3.0])

        // Act
        let result = try NpyParser.parse(data)

        // Assert
        XCTAssertEqual(result.shape, [3])
        XCTAssertEqual(result.data, [1.0, 2.0, 3.0])
    }

    // MARK: - Helpers

    /// Create a valid v1 .npy file in memory
    private func makeNpyV1(shape: [Int], floats: [Float32]) -> Data {
        var data = Data()

        // Magic
        data.append(contentsOf: [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59])

        // Version 1.0
        data.append(contentsOf: [1, 0])

        // Header
        let shapeStr = shape.map { String($0) }.joined(separator: ", ")
        let headerContent = "{'descr': '<f4', 'fortran_order': False, 'shape': (\(shapeStr),), }"

        // Pad header to align to 64 bytes
        let preHeaderLen = 6 + 2 + 2 // magic + version + header_len field
        var headerBytes = Array(headerContent.utf8)
        let totalLen = preHeaderLen + headerBytes.count + 1 // +1 for newline
        let padding = (64 - (totalLen % 64)) % 64
        for _ in 0..<padding {
            headerBytes.append(0x20) // space
        }
        headerBytes.append(0x0A) // newline

        // Header length (2 bytes little-endian)
        let headerLen = UInt16(headerBytes.count)
        data.append(UInt8(headerLen & 0xFF))
        data.append(UInt8((headerLen >> 8) & 0xFF))

        // Header data
        data.append(contentsOf: headerBytes)

        // Float data
        for f in floats {
            var value = f
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        return data
    }

    /// Create a valid v2 .npy file in memory
    private func makeNpyV2(shape: [Int], floats: [Float32]) -> Data {
        var data = Data()

        // Magic
        data.append(contentsOf: [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59])

        // Version 2.0
        data.append(contentsOf: [2, 0])

        // Header
        let shapeStr = shape.map { String($0) }.joined(separator: ", ")
        let headerContent = "{'descr': '<f4', 'fortran_order': False, 'shape': (\(shapeStr),), }"

        var headerBytes = Array(headerContent.utf8)
        headerBytes.append(0x0A) // newline

        // Header length (4 bytes little-endian for v2)
        let headerLen = UInt32(headerBytes.count)
        data.append(UInt8(headerLen & 0xFF))
        data.append(UInt8((headerLen >> 8) & 0xFF))
        data.append(UInt8((headerLen >> 16) & 0xFF))
        data.append(UInt8((headerLen >> 24) & 0xFF))

        // Header data
        data.append(contentsOf: headerBytes)

        // Float data
        for f in floats {
            var value = f
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        return data
    }

    /// Create a raw .npy v1 file with specific dtype and data size (for error testing)
    private func makeNpyV1Raw(dtype: String = "<f4", shapeStr: String, floatBytes: Int) -> Data {
        var data = Data()

        // Magic + version
        data.append(contentsOf: [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59, 1, 0])

        // Header
        let headerContent = "{'descr': '\(dtype)', 'fortran_order': False, 'shape': (\(shapeStr)), }"
        var headerBytes = Array(headerContent.utf8)
        headerBytes.append(0x0A)

        let headerLen = UInt16(headerBytes.count)
        data.append(UInt8(headerLen & 0xFF))
        data.append(UInt8((headerLen >> 8) & 0xFF))
        data.append(contentsOf: headerBytes)

        // Append only floatBytes of data
        data.append(contentsOf: [UInt8](repeating: 0, count: floatBytes))

        return data
    }
}
