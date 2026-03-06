import Foundation

/// Entidad que representa una carpeta para organizar proyectos
final class Folder {
    typealias FolderId = Identifier<Folder>

    // MARK: - Properties

    private(set) var id: FolderId
    private(set) var name: FolderName
    private(set) var colorHex: String
    private(set) var sortOrder: Int
    private(set) var createdAt: Date
    private(set) var updatedAt: Date

    // MARK: - Initializers

    /// Crea una nueva carpeta
    init(name: FolderName, colorHex: String = "#007AFF", sortOrder: Int = 0) {
        self.id = FolderId()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Reconstitución desde persistencia
    init(
        id: FolderId,
        name: FolderName,
        colorHex: String,
        sortOrder: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Mutations

    func rename(_ newName: FolderName) {
        self.name = newName
        touch()
    }

    func updateColor(_ hex: String) {
        self.colorHex = hex
        touch()
    }

    func updateSortOrder(_ order: Int) {
        self.sortOrder = order
        touch()
    }

    // MARK: - Private

    private func touch() {
        self.updatedAt = Date()
    }
}
