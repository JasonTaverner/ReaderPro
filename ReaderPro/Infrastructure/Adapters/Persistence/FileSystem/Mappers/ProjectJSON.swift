import Foundation

/// Representación JSON del Project para persistencia
struct ProjectJSON: Codable {
    let id: String
    let name: String
    let text: String?
    let voiceId: String
    let voiceName: String
    let voiceLanguage: String
    let voiceProvider: String
    let speed: Double
    let pitch: Double?  // Kept optional for backward compatibility with old JSON files
    let audioPath: String?
    let status: String
    let entries: [AudioEntryJSON]
    let coverImagePath: String?
    let folderId: String?  // Optional for backward compatibility
    let folderName: String?  // Optional for backward compatibility with UUID-based folders
    let createdAt: TimeInterval
    let updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case text
        case voiceId = "voice_id"
        case voiceName = "voice_name"
        case voiceLanguage = "voice_language"
        case voiceProvider = "voice_provider"
        case speed
        case pitch
        case audioPath = "audio_path"
        case status
        case entries
        case coverImagePath = "cover_image_path"
        case folderId = "folder_id"
        case folderName = "folder_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Representación JSON de AudioEntry
struct AudioEntryJSON: Codable {
    let id: String
    let text: String
    let audioPath: String?
    let imagePath: String?
    let isRead: Bool?
    let createdAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case audioPath = "audio_path"
        case imagePath = "image_path"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
