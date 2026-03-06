import Foundation

/// Port para el repositorio de carpetas
protocol FolderRepositoryPort {
    func save(_ folder: Folder) async throws
    func findById(_ id: Identifier<Folder>) async throws -> Folder?
    func findAll() async throws -> [Folder]
    func delete(_ id: Identifier<Folder>) async throws
}
