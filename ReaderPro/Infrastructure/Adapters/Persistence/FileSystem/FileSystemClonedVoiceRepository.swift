import Foundation

/// File-system backed repository for cloned voice profiles.
/// Storage structure:
/// {baseDirectory}/ClonedVoices/{uuid}/
///   ├── profile.json
///   └── reference.{ext}
final class FileSystemClonedVoiceRepository: ClonedVoiceRepositoryPort {

    // MARK: - Properties

    let baseDirectory: URL
    private let fileManager: FileManager

    // MARK: - Codable Model

    private struct ProfileJSON: Codable {
        let id: String
        let name: String
        let audioFileName: String
        let referenceText: String
        let audioDuration: TimeInterval
        let createdAt: Date
    }

    // MARK: - Initialization

    init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
            .appendingPathComponent("ClonedVoices", isDirectory: true)
        self.fileManager = fileManager
        createBaseDirectoryIfNeeded()
    }

    // MARK: - ClonedVoiceRepositoryPort

    func save(_ profile: ClonedVoiceProfile, audioData: Data) async throws {
        let profileDir = baseDirectory.appendingPathComponent(profile.id, isDirectory: true)

        // Create directory
        if !fileManager.fileExists(atPath: profileDir.path) {
            try fileManager.createDirectory(
                at: profileDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Write audio file
        let audioURL = profileDir.appendingPathComponent(profile.audioFileName)
        try audioData.write(to: audioURL, options: .atomic)

        // Write profile.json
        let json = ProfileJSON(
            id: profile.id,
            name: profile.name,
            audioFileName: profile.audioFileName,
            referenceText: profile.referenceText,
            audioDuration: profile.audioDuration,
            createdAt: profile.createdAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(json)

        let jsonURL = profileDir.appendingPathComponent("profile.json")
        try data.write(to: jsonURL, options: .atomic)

        print("[ClonedVoiceRepo] Saved profile '\(profile.name)' at \(profileDir.path)")
    }

    func findAll() async throws -> [ClonedVoiceProfile] {
        guard fileManager.fileExists(atPath: baseDirectory.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let directories = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }

        var profiles: [ClonedVoiceProfile] = []

        for dir in directories {
            let jsonURL = dir.appendingPathComponent("profile.json")
            guard fileManager.fileExists(atPath: jsonURL.path) else { continue }

            do {
                let data = try Data(contentsOf: jsonURL)
                let json = try decoder.decode(ProfileJSON.self, from: data)
                profiles.append(ClonedVoiceProfile(
                    id: json.id,
                    name: json.name,
                    audioFileName: json.audioFileName,
                    referenceText: json.referenceText,
                    audioDuration: json.audioDuration,
                    createdAt: json.createdAt
                ))
            } catch {
                continue
            }
        }

        return profiles.sorted { $0.createdAt > $1.createdAt }
    }

    func findById(_ id: String) async throws -> ClonedVoiceProfile? {
        let jsonURL = baseDirectory
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("profile.json")

        guard fileManager.fileExists(atPath: jsonURL.path) else { return nil }

        let data = try Data(contentsOf: jsonURL)
        let json = try decoder.decode(ProfileJSON.self, from: data)

        return ClonedVoiceProfile(
            id: json.id,
            name: json.name,
            audioFileName: json.audioFileName,
            referenceText: json.referenceText,
            audioDuration: json.audioDuration,
            createdAt: json.createdAt
        )
    }

    func delete(_ id: String) async throws {
        let profileDir = baseDirectory.appendingPathComponent(id, isDirectory: true)
        if fileManager.fileExists(atPath: profileDir.path) {
            try fileManager.removeItem(at: profileDir)
            print("[ClonedVoiceRepo] Deleted profile: \(id)")
        }
    }

    func audioURL(for profile: ClonedVoiceProfile) -> URL {
        baseDirectory
            .appendingPathComponent(profile.id, isDirectory: true)
            .appendingPathComponent(profile.audioFileName)
    }

    // MARK: - Private

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
