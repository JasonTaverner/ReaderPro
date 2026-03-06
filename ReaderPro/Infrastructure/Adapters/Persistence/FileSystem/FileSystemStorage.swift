import Foundation

/// Storage de archivos basado en sistema de archivos que implementa FileStoragePort
/// Maneja tanto texto como datos binarios (textos, imágenes, etc.)
final class FileSystemStorage: FileStoragePort {

    // MARK: - Properties

    private let baseDirectoryURL: URL
    private let fileManager: FileManager

    // MARK: - Initialization

    /// Inicializa el storage con un directorio base
    /// - Parameter baseDirectory: Directorio base donde se almacenarán los archivos
    init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectoryURL = baseDirectory
        self.fileManager = fileManager
        createBaseDirectoryIfNeeded()
    }

    // MARK: - FileStoragePort Implementation

    func saveText(_ text: String, to path: String) async throws {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        // Create intermediate directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        try createDirectory(at: directoryURL)

        // Write text to file using UTF-8 encoding
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw InfrastructureError.fileWriteFailed(fileURL.path)
        }
    }

    func loadText(from path: String) async throws -> String {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw InfrastructureError.fileNotFound(path)
        }

        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw InfrastructureError.fileReadFailed(path)
        }
    }

    func save(data: Data, to path: String) async throws {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        // Create intermediate directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        try createDirectory(at: directoryURL)

        // Write data to file
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw InfrastructureError.fileWriteFailed(fileURL.path)
        }
    }

    func load(from path: String) async throws -> Data {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw InfrastructureError.fileNotFound(path)
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw InfrastructureError.fileReadFailed(path)
        }
    }

    func exists(path: String) async -> Bool {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func delete(path: String) async throws {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        // Only attempt to delete if file exists (idempotent)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw InfrastructureError.fileWriteFailed("Failed to delete: \(path)")
        }
    }

    func generateNumberedPath(baseDirectory: String, number: Int, extension ext: String) -> String {
        // Format: baseDirectory/001.ext, baseDirectory/002.ext, etc.
        let paddedNumber = String(format: "%03d", number)
        return "\(baseDirectory)/\(paddedNumber).\(ext)"
    }

    func createDirectory(at path: String) async throws {
        let directoryURL = baseDirectoryURL.appendingPathComponent(path)
        try createDirectory(at: directoryURL)
    }

    // MARK: - Private Helpers

    /// Creates the base directory if it doesn't exist
    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try? fileManager.createDirectory(
                at: baseDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// Creates a directory if it doesn't exist
    private func createDirectory(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw InfrastructureError.directoryCreationFailed(url.path)
            }
        }
    }
}
