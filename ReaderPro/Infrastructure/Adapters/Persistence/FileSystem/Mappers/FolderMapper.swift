import Foundation

/// Mapper que convierte entre Folder del dominio y FolderJSON para persistencia
final class FolderMapper {

    // MARK: - Domain to JSON

    func toJSON(_ folder: Folder) -> FolderJSON {
        FolderJSON(
            id: folder.id.value.uuidString,
            name: folder.name.value,
            colorHex: folder.colorHex,
            sortOrder: folder.sortOrder,
            createdAt: folder.createdAt.timeIntervalSince1970,
            updatedAt: folder.updatedAt.timeIntervalSince1970
        )
    }

    // MARK: - JSON to Domain

    func toDomain(_ json: FolderJSON) throws -> Folder {
        guard let uuid = UUID(uuidString: json.id) else {
            throw InfrastructureError.invalidProjectData("Invalid folder UUID: \(json.id)")
        }

        let id = Identifier<Folder>(uuid)
        let name = try FolderName(json.name)

        return Folder(
            id: id,
            name: name,
            colorHex: json.colorHex,
            sortOrder: json.sortOrder,
            createdAt: Date(timeIntervalSince1970: json.createdAt),
            updatedAt: Date(timeIntervalSince1970: json.updatedAt)
        )
    }
}
