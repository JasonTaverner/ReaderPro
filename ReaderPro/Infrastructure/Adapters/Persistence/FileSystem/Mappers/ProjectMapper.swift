import Foundation

/// Mapper que convierte entre Project del dominio y ProjectJSON para persistencia
final class ProjectMapper {

    // MARK: - Domain to JSON

    func toJSON(_ project: Project) -> ProjectJSON {
        ProjectJSON(
            id: project.id.value.uuidString,
            name: project.name.value,
            text: project.text?.value,
            voiceId: project.voiceConfiguration.voiceId,
            voiceName: project.voice.name,
            voiceLanguage: project.voice.language,
            voiceProvider: project.voice.provider.rawValue,
            speed: project.voiceConfiguration.speed.value,
            pitch: nil,
            audioPath: project.audioPath,
            status: project.status.rawValue,
            entries: project.entries.map { toEntryJSON($0) },
            coverImagePath: project.coverImagePath,
            folderId: project.folderId?.value.uuidString,
            folderName: project.folderName,
            createdAt: project.createdAt.timeIntervalSince1970,
            updatedAt: project.updatedAt.timeIntervalSince1970
        )
    }

    private func toEntryJSON(_ entry: AudioEntry) -> AudioEntryJSON {
        AudioEntryJSON(
            id: entry.id.value.uuidString,
            text: entry.text.value,
            audioPath: entry.audioPath,
            imagePath: entry.imagePath,
            isRead: entry.isRead,
            createdAt: entry.createdAt.timeIntervalSince1970
        )
    }

    // MARK: - JSON to Domain

    func toDomain(_ json: ProjectJSON) throws -> Project {
        // 1. Reconstruct Value Objects
        guard let uuid = UUID(uuidString: json.id) else {
            throw InfrastructureError.invalidProjectData("Invalid UUID: \(json.id)")
        }

        let id = Identifier<Project>(uuid)
        let name = try ProjectName(json.name)
        let text: TextContent?
        if let jsonText = json.text, !jsonText.isEmpty {
            text = try TextContent(jsonText)
        } else {
            text = nil
        }

        let speed = try VoiceConfiguration.Speed(json.speed)
        let voiceConfiguration = VoiceConfiguration(
            voiceId: json.voiceId,
            speed: speed
        )

        // 2. Reconstruct Voice
        guard let provider = Voice.TTSProvider(rawValue: json.voiceProvider) else {
            throw InfrastructureError.invalidProjectData("Invalid provider: \(json.voiceProvider)")
        }

        let voice = Voice(
            id: json.voiceId,
            name: json.voiceName,
            language: json.voiceLanguage,
            provider: provider,
            isDefault: false
        )

        // 3. Reconstruct Status
        guard let status = ProjectStatus(rawValue: json.status) else {
            throw InfrastructureError.invalidProjectData("Invalid status: \(json.status)")
        }

        // 4. Reconstruct Entries
        let entries = try json.entries.map { try toEntryDomain($0) }

        // 5. Reconstruct Dates
        let createdAt = Date(timeIntervalSince1970: json.createdAt)
        let updatedAt = Date(timeIntervalSince1970: json.updatedAt)

        // 6. Reconstruct folderId (optional, backward compatible)
        let folderId: Identifier<Folder>?
        if let folderIdStr = json.folderId, let folderUUID = UUID(uuidString: folderIdStr) {
            folderId = Identifier<Folder>(folderUUID)
        } else {
            folderId = nil
        }

        // 7. Use reconstitution constructor
        return Project(
            id: id,
            name: name,
            text: text,
            voiceConfiguration: voiceConfiguration,
            voice: voice,
            audioPath: json.audioPath,
            status: status,
            entries: entries,
            coverImagePath: json.coverImagePath,
            folderId: folderId,
            folderName: json.folderName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func toEntryDomain(_ json: AudioEntryJSON) throws -> AudioEntry {
        guard let uuid = UUID(uuidString: json.id) else {
            throw InfrastructureError.invalidProjectData("Invalid entry UUID: \(json.id)")
        }

        let id = EntryId(uuid)
        let text = try TextContent(json.text)
        let createdAt = Date(timeIntervalSince1970: json.createdAt)

        return AudioEntry(
            id: id,
            text: text,
            audioPath: json.audioPath,
            imagePath: json.imagePath,
            isRead: json.isRead ?? false,
            createdAt: createdAt
        )
    }

    // MARK: - JSON Encoding/Decoding

    func encode(_ project: Project) throws -> Data {
        let json = toJSON(project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(json)
        } catch {
            throw InfrastructureError.jsonEncodingFailed(error)
        }
    }

    func decode(_ data: Data) throws -> Project {
        let decoder = JSONDecoder()
        do {
            let json = try decoder.decode(ProjectJSON.self, from: data)
            return try toDomain(json)
        } catch let error as InfrastructureError {
            throw error
        } catch {
            throw InfrastructureError.jsonDecodingFailed(error)
        }
    }
}
