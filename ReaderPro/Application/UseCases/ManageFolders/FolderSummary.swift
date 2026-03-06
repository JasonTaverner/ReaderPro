import Foundation

/// DTO resumido de una carpeta para listados
struct FolderSummary: Identifiable, Equatable {
    let id: String
    let folderId: Identifier<Folder>
    let name: String
    let colorHex: String
    let sortOrder: Int
    let projectCount: Int

    init(
        folderId: Identifier<Folder>,
        name: String,
        colorHex: String,
        sortOrder: Int,
        projectCount: Int
    ) {
        self.id = folderId.value.uuidString
        self.folderId = folderId
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.projectCount = projectCount
    }

    static func == (lhs: FolderSummary, rhs: FolderSummary) -> Bool {
        lhs.folderId == rhs.folderId
    }
}
