import Foundation

/// Repositorio basado en sistema de archivos que implementa ProjectRepositoryPort
/// Estructura:
/// ~/Documents/ReaderProLibrary/
/// ├── ProjectName/
/// │   ├── project.json
/// │   ├── 001.txt, 001.wav, 001.png
/// │   └── exports/
final class FileSystemProjectRepository: ProjectRepositoryPort {

    // MARK: - Properties

    private let baseDirectory: URL
    private let fileManager: FileManager
    private let mapper: ProjectMapper

    // MARK: - Initialization

    /// Inicializa el repositorio con un directorio base
    /// - Parameter baseDirectory: Directorio base donde se almacenarán los proyectos
    ///                            Por defecto: ~/Documents/ReaderProLibrary/
    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            // Default: ~/Documents/ReaderProLibrary/
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
        self.mapper = ProjectMapper()

        createBaseDirectoryIfNeeded()
    }

    // MARK: - ProjectRepositoryPort Implementation

    func save(_ project: Project) async throws {
        print("[FileSystemProjectRepository] Saving project: \(project.name.value) (ID: \(project.id.value))")

        // 1. Determine the desired folder name from project name
        let desiredFolderName = sanitizeFolderName(project.name.value)

        // 2. Determine the current folder on disk
        let currentFolderName = project.folderName
        let currentDirectory: URL?
        if let current = currentFolderName {
            let url = baseDirectory.appendingPathComponent(current, isDirectory: true)
            currentDirectory = fileManager.fileExists(atPath: url.path) ? url : nil
        } else {
            currentDirectory = nil
        }

        // 3. Check for legacy UUID-based folder (migration)
        let legacyDirectory = baseDirectory.appendingPathComponent(project.id.value.uuidString, isDirectory: true)
        let hasLegacyDir = currentDirectory == nil && fileManager.fileExists(atPath: legacyDirectory.path)

        // 4. Resolve the final folder name (handle collisions)
        let finalFolderName: String
        if let current = currentFolderName, currentDirectory != nil, current == desiredFolderName {
            // Name hasn't changed, use current
            finalFolderName = current
        } else {
            // Name changed or new project — resolve uniqueness
            finalFolderName = resolveUniqueFolderName(desiredFolderName, excludingCurrent: currentFolderName)
        }
        let targetDirectory = baseDirectory.appendingPathComponent(finalFolderName, isDirectory: true)

        // 5. Handle migration from UUID folder
        if hasLegacyDir {
            print("[FileSystemProjectRepository] Migrating UUID folder → \(finalFolderName)")
            let oldFolderName = project.id.value.uuidString
            try migrateFolder(from: legacyDirectory, to: targetDirectory)
            project.rewritePaths(from: oldFolderName, to: finalFolderName)
            migrateAudioFileNames(in: targetDirectory, project: project, folderName: finalFolderName)
        }
        // 6. Handle rename (current folder exists but name changed)
        else if let current = currentFolderName, let currentDir = currentDirectory, current != finalFolderName {
            print("[FileSystemProjectRepository] Renaming folder: \(current) → \(finalFolderName)")
            try migrateFolder(from: currentDir, to: targetDirectory)
            project.rewritePaths(from: current, to: finalFolderName)
        }
        // 7. New project — just create the directory
        else if currentDirectory == nil && !hasLegacyDir {
            try createDirectory(at: targetDirectory)
        }

        // 8. Update project's folderName
        project.updateFolderName(finalFolderName)

        // 9. Encode project to JSON
        let jsonData = try mapper.encode(project)

        // 10. Write to project.json file
        let jsonFileURL = targetDirectory.appendingPathComponent("project.json")
        try jsonData.write(to: jsonFileURL, options: .atomic)

        print("[FileSystemProjectRepository] Project saved successfully to: \(jsonFileURL.path)")
    }

    func findById(_ id: Identifier<Project>) async throws -> Project? {
        // Scan all project directories to find the one with matching ID
        let projectDirectories = try getProjectDirectories()

        for directory in projectDirectories {
            let jsonFileURL = directory.appendingPathComponent("project.json")

            guard fileManager.fileExists(atPath: jsonFileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: jsonFileURL)
                let project = try mapper.decode(data)

                if project.id == id {
                    // Ensure folderName is set (backward compatibility)
                    if project.folderName == nil {
                        project.updateFolderName(directory.lastPathComponent)
                    }
                    return project
                }
            } catch {
                // Skip invalid project files
                continue
            }
        }

        return nil
    }

    func findAll() async throws -> [Project] {
        let projectDirectories = try getProjectDirectories()
        var projects: [Project] = []
        for directory in projectDirectories {
            let jsonFileURL = directory.appendingPathComponent("project.json")

            guard fileManager.fileExists(atPath: jsonFileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: jsonFileURL)
                let project = try mapper.decode(data)
                // Ensure folderName is set (backward compatibility)
                if project.folderName == nil {
                    project.updateFolderName(directory.lastPathComponent)
                }
                projects.append(project)
            } catch {
                // Skip invalid project files
                continue
            }
        }

        // Sort by updatedAt descending (most recent first)
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func search(query: String) async throws -> [Project] {
        let allProjects = try await findAll()

        let lowercasedQuery = query.lowercased()

        return allProjects.filter { project in
            project.name.value.lowercased().contains(lowercasedQuery) ||
            (project.text?.value.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    func delete(_ id: Identifier<Project>) async throws {
        // Find the project to get its directory
        guard let project = try await findById(id) else {
            // If project doesn't exist, silently succeed (idempotent delete)
            return
        }

        // Try folderName-based directory first, then fallback to UUID
        let projectDirectory: URL
        if let folderName = project.folderName {
            projectDirectory = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        } else {
            projectDirectory = baseDirectory.appendingPathComponent(project.id.value.uuidString, isDirectory: true)
        }

        // Remove the entire project directory
        if fileManager.fileExists(atPath: projectDirectory.path) {
            try fileManager.removeItem(at: projectDirectory)
        }
    }

    func findByStatus(_ status: ProjectStatus) async throws -> [Project] {
        let allProjects = try await findAll()
        return allProjects.filter { $0.status == status }
    }

    func findCreatedAfter(_ date: Date) async throws -> [Project] {
        let allProjects = try await findAll()
        return allProjects.filter { $0.createdAt > date }
    }

    // MARK: - Folder Name Helpers

    /// Sanitizes a project name for use as a folder name on disk
    /// Replaces filesystem-prohibited characters with underscores
    static func sanitizeFolderName(_ name: String) -> String {
        let prohibited: CharacterSet = {
            var set = CharacterSet()
            // Characters not allowed in folder names on macOS/POSIX
            set.insert(charactersIn: "/:\\*?\"<>|")
            // Also remove control characters
            set.formUnion(.controlCharacters)
            return set
        }()

        var sanitized = name
            .components(separatedBy: prohibited)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading dots (hidden files on Unix)
        while sanitized.hasPrefix(".") {
            sanitized = String(sanitized.dropFirst())
        }

        // Ensure not empty
        if sanitized.isEmpty {
            sanitized = "Unnamed Project"
        }

        // Limit length to 255 (filesystem limit)
        if sanitized.count > 255 {
            sanitized = String(sanitized.prefix(255))
        }

        return sanitized
    }

    /// Instance method wrapper
    private func sanitizeFolderName(_ name: String) -> String {
        Self.sanitizeFolderName(name)
    }

    /// Resolves a unique folder name by appending " 2", " 3", etc. if needed
    private func resolveUniqueFolderName(_ desired: String, excludingCurrent: String?) -> String {
        var candidate = desired
        var suffix = 2

        while true {
            let candidateURL = baseDirectory.appendingPathComponent(candidate, isDirectory: true)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                // Doesn't exist on disk — it's free
                return candidate
            }
            if candidate == excludingCurrent {
                // It's our own current folder — we can reuse it
                return candidate
            }
            candidate = "\(desired) \(suffix)"
            suffix += 1
        }
    }

    // MARK: - Migration Helpers

    /// Moves a project folder from one location to another
    private func migrateFolder(from source: URL, to destination: URL) throws {
        // If destination already exists (shouldn't happen), bail out
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw InfrastructureError.directoryCreationFailed(
                "Destination already exists: \(destination.path)"
            )
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    /// Renames UUID-named audio files to sequential numbering (001.wav, 002.wav, etc.)
    /// Updates the project's entry audioPath references in-place
    private func migrateAudioFileNames(in directory: URL, project: Project, folderName: String) {
        for (index, entry) in project.entries.enumerated() {
            guard let audioPath = entry.audioPath else { continue }

            let audioURL = baseDirectory.appendingPathComponent(audioPath)
            let ext = audioURL.pathExtension
            guard !ext.isEmpty else { continue }

            // Check if already numbered (e.g., "001.wav")
            let currentFilename = audioURL.deletingPathExtension().lastPathComponent
            if currentFilename.count == 3, Int(currentFilename) != nil {
                continue // Already sequential
            }

            // Generate new sequential name
            let newFilename = String(format: "%03d.%@", index + 1, ext)
            let newURL = directory.appendingPathComponent(newFilename)
            let newRelativePath = "\(folderName)/\(newFilename)"

            // Only rename if file exists and destination doesn't
            guard fileManager.fileExists(atPath: audioURL.path),
                  !fileManager.fileExists(atPath: newURL.path) else { continue }

            do {
                try fileManager.moveItem(at: audioURL, to: newURL)
                // Update entry's audioPath
                var updatedEntry = AudioEntry(
                    id: entry.id,
                    text: entry.text,
                    audioPath: newRelativePath,
                    imagePath: entry.imagePath,
                    createdAt: entry.createdAt
                )
                _ = updatedEntry // suppress warning
                try? project.updateEntry(AudioEntry(
                    id: entry.id,
                    text: entry.text,
                    audioPath: newRelativePath,
                    imagePath: entry.imagePath,
                    createdAt: entry.createdAt
                ))
            } catch {
                print("[FileSystemProjectRepository] Failed to rename audio: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    /// Creates the base directory if it doesn't exist
    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(
                at: baseDirectory,
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

    /// Gets all project directories in the base directory
    private func getProjectDirectories() throws -> [URL] {
        guard fileManager.fileExists(atPath: baseDirectory.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        // Filter for directories only
        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
    }
}
