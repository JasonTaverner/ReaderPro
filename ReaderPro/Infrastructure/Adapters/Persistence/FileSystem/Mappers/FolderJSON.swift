import Foundation

/// Representación JSON del Folder para persistencia
struct FolderJSON: Codable {
    let id: String
    let name: String
    let colorHex: String
    let sortOrder: Int
    let createdAt: TimeInterval
    let updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex = "color_hex"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
