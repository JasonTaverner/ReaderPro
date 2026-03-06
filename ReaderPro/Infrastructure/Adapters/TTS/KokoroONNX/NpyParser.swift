import Foundation

/// Parser for NumPy .npy binary format
/// Reference: https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html
///
/// Format:
/// - Magic: \x93NUMPY (6 bytes)
/// - Major version: 1 byte
/// - Minor version: 1 byte
/// - Header length: 2 bytes (v1) or 4 bytes (v2)
/// - Header: ASCII string with Python dict {'descr': '<f4', 'fortran_order': False, 'shape': (510, 1, 256)}
/// - Data: raw binary
enum NpyParser {

    // MARK: - Types

    struct NpyArray {
        let shape: [Int]
        let data: [Float32]
    }

    enum NpyError: LocalizedError {
        case invalidMagic
        case unsupportedVersion(major: UInt8, minor: UInt8)
        case headerParseFailed(String)
        case unsupportedDtype(String)
        case dataSizeMismatch(expected: Int, got: Int)

        var errorDescription: String? {
            switch self {
            case .invalidMagic:
                return "Not a valid .npy file (invalid magic bytes)"
            case .unsupportedVersion(let major, let minor):
                return "Unsupported .npy version \(major).\(minor)"
            case .headerParseFailed(let reason):
                return "Failed to parse .npy header: \(reason)"
            case .unsupportedDtype(let dtype):
                return "Unsupported dtype: \(dtype) (only float32 supported)"
            case .dataSizeMismatch(let expected, let got):
                return "Data size mismatch: expected \(expected) bytes, got \(got)"
            }
        }
    }

    // MARK: - Magic

    private static let magic: [UInt8] = [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59] // \x93NUMPY

    // MARK: - Public API

    /// Parse a .npy file from raw Data
    /// - Parameter data: Raw bytes of a .npy file
    /// - Returns: Parsed NpyArray with shape and float32 data
    static func parse(_ data: Data) throws -> NpyArray {
        var offset = 0

        // 1. Validate magic bytes (6 bytes)
        guard data.count >= 10 else {
            throw NpyError.invalidMagic
        }

        let magicBytes = [UInt8](data[0..<6])
        guard magicBytes == magic else {
            throw NpyError.invalidMagic
        }
        offset = 6

        // 2. Read version (2 bytes)
        let majorVersion = data[offset]
        let minorVersion = data[offset + 1]
        offset += 2

        // 3. Read header length
        let headerLength: Int
        if majorVersion == 1 {
            // v1: 2 bytes little-endian
            guard data.count >= offset + 2 else {
                throw NpyError.headerParseFailed("File too short for header length")
            }
            headerLength = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2
        } else if majorVersion == 2 {
            // v2: 4 bytes little-endian
            guard data.count >= offset + 4 else {
                throw NpyError.headerParseFailed("File too short for header length")
            }
            headerLength = Int(data[offset])
                | (Int(data[offset + 1]) << 8)
                | (Int(data[offset + 2]) << 16)
                | (Int(data[offset + 3]) << 24)
            offset += 4
        } else {
            throw NpyError.unsupportedVersion(major: majorVersion, minor: minorVersion)
        }

        // 4. Read and parse header string
        guard data.count >= offset + headerLength else {
            throw NpyError.headerParseFailed("File too short for header data")
        }

        let headerData = data[offset..<(offset + headerLength)]
        guard let headerString = String(data: headerData, encoding: .ascii) else {
            throw NpyError.headerParseFailed("Could not decode header as ASCII")
        }
        offset += headerLength

        // 5. Parse header dict
        let (dtype, shape) = try parseHeader(headerString)

        // 6. Validate dtype (we only support float32)
        guard dtype == "<f4" || dtype == "float32" || dtype == "<f" else {
            throw NpyError.unsupportedDtype(dtype)
        }

        // 7. Calculate expected data size
        let totalElements = shape.reduce(1, *)
        let expectedBytes = totalElements * 4 // float32 = 4 bytes
        let availableBytes = data.count - offset

        guard availableBytes >= expectedBytes else {
            throw NpyError.dataSizeMismatch(expected: expectedBytes, got: availableBytes)
        }

        // 8. Read float32 data (little-endian, which is native on ARM/x86)
        let floatData = data[offset..<(offset + expectedBytes)]
        let floats = floatData.withUnsafeBytes { buffer -> [Float32] in
            let typed = buffer.bindMemory(to: Float32.self)
            return Array(typed)
        }

        return NpyArray(shape: shape, data: floats)
    }

    // MARK: - Header Parsing

    /// Parse the Python dict header string
    /// Example: "{'descr': '<f4', 'fortran_order': False, 'shape': (510, 1, 256), }\n"
    static func parseHeader(_ header: String) throws -> (dtype: String, shape: [Int]) {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract descr
        guard let dtype = extractValue(from: trimmed, key: "descr") else {
            throw NpyError.headerParseFailed("Could not find 'descr' in header")
        }

        // Extract shape
        guard let shapeStr = extractTupleValue(from: trimmed, key: "shape") else {
            throw NpyError.headerParseFailed("Could not find 'shape' in header")
        }

        let shape = parseShape(shapeStr)

        return (dtype, shape)
    }

    /// Extract a quoted string value for a given key from a Python dict string
    private static func extractValue(from header: String, key: String) -> String? {
        // Match patterns like 'descr': '<f4' or 'descr': "float32"
        let patterns = [
            "'\(key)':\\s*'([^']*)'",
            "'\(key)':\\s*\"([^\"]*)\""
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                in: header,
                range: NSRange(header.startIndex..., in: header)
               ) {
                if let range = Range(match.range(at: 1), in: header) {
                    return String(header[range])
                }
            }
        }
        return nil
    }

    /// Extract the tuple value for 'shape' from a Python dict string
    private static func extractTupleValue(from header: String, key: String) -> String? {
        let pattern = "'\(key)':\\s*\\(([^)]*)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: header,
                range: NSRange(header.startIndex..., in: header)
              ),
              let range = Range(match.range(at: 1), in: header) else {
            return nil
        }
        return String(header[range])
    }

    /// Parse a shape string like "510, 1, 256" into [510, 1, 256]
    private static func parseShape(_ shapeStr: String) -> [Int] {
        shapeStr
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}
