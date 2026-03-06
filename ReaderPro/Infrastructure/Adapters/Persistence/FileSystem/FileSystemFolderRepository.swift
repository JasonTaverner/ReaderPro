import Foundation

/// Repositorio basado en sistema de archivos que implementa FolderRepositoryPort
/// Almacena todas las carpetas en un archivo folders.json en el directorio base
final class FileSystemFolderRepository: FolderRepositoryPort {

    // MARK: - Properties

    private let baseDirectory: URL
    private let fileManager: FileManager
    private let mapper: FolderMapper

    private var foldersFileURL: URL {
        baseDirectory.appendingPathComponent("folders.json")
    }

    // MARK: - Initialization

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let documentsDirectory = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            self.baseDirectory = documentsDirectory.appendingPathComponent(
                "ReaderProLibrary",
                isDirectory: true
            )
        }

        self.fileManager = fileManager
        self.mapper = FolderMapper()

        createBaseDirectoryIfNeeded()
    }

    // MARK: - FolderRepositoryPort Implementation

    func save(_ folder: Folder) async throws {
        var folders = try loadAllFromDisk()

        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        } else {
            folders.append(folder)
        }

        try writeToDisk(folders)
    }

    func findById(_ id: Identifier<Folder>) async throws -> Folder? {
        let folders = try loadAllFromDisk()
        return folders.first(where: { $0.id == id })
    }

    func findAll() async throws -> [Folder] {
        try loadAllFromDisk().sorted { $0.sortOrder < $1.sortOrder }
    }

    func delete(_ id: Identifier<Folder>) async throws {
        var folders = try loadAllFromDisk()
        folders.removeAll { $0.id == id }
        try writeToDisk(folders)
    }

    // MARK: - Private Helpers

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func loadAllFromDisk() throws -> [Folder] {
        guard fileManager.fileExists(atPath: foldersFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: foldersFileURL)
            let jsonArray = try JSONDecoder().decode([FolderJSON].self, from: data)
            return try jsonArray.compactMap { json in
                try? mapper.toDomain(json)
            }
        } catch {
            print("[FileSystemFolderRepository] Error loading folders: \(error)")
            return []
        }
    }

    private func writeToDisk(_ folders: [Folder]) throws {
        let jsonArray = folders.map { mapper.toJSON($0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(jsonArray)
            try data.write(to: foldersFileURL, options: .atomic)
        } catch {
            throw InfrastructureError.jsonEncodingFailed(error)
        }
    }
}
