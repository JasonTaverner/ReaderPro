import Foundation

/// Value Object que representa el nombre validado de una carpeta
struct FolderName: Equatable {
    let value: String

    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw DomainError.invalidFolderName("El nombre no puede estar vacío")
        }

        guard trimmed.count <= 50 else {
            throw DomainError.invalidFolderName("El nombre excede 50 caracteres")
        }

        self.value = trimmed
    }
}
