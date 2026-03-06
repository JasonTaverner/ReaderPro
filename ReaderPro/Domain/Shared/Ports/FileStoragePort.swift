import Foundation

/// Port para almacenamiento de archivos genéricos
/// Define la interfaz para guardar texto, imágenes y otros archivos
protocol FileStoragePort {
    /// Guarda datos en un archivo
    /// - Parameters:
    ///   - data: Los datos a guardar
    ///   - path: Path donde guardar el archivo
    /// - Throws: Error si falla el guardado
    func save(data: Data, to path: String) async throws

    /// Guarda texto en un archivo
    /// - Parameters:
    ///   - text: El texto a guardar
    ///   - path: Path donde guardar el archivo
    /// - Throws: Error si falla el guardado
    func saveText(_ text: String, to path: String) async throws

    /// Carga texto desde un archivo
    /// - Parameter path: Path al archivo
    /// - Returns: El texto cargado
    /// - Throws: Error si el archivo no existe o no se puede leer
    func loadText(from path: String) async throws -> String

    /// Carga datos desde un archivo
    /// - Parameter path: Path al archivo
    /// - Returns: Los datos cargados
    /// - Throws: Error si el archivo no existe
    func load(from path: String) async throws -> Data

    /// Verifica si existe un archivo
    /// - Parameter path: Path a verificar
    /// - Returns: true si existe, false si no
    func exists(path: String) async -> Bool

    /// Elimina un archivo
    /// - Parameter path: Path al archivo a eliminar
    /// - Throws: Error si falla la eliminación
    func delete(path: String) async throws

    /// Genera un path para un archivo numerado (001.txt, 002.wav, etc.)
    /// - Parameters:
    ///   - baseDirectory: Directorio base
    ///   - number: Número secuencial (1, 2, 3...)
    ///   - extension: Extensión del archivo (txt, wav, png)
    /// - Returns: Path completo generado
    func generateNumberedPath(
        baseDirectory: String,
        number: Int,
        extension: String
    ) -> String

    /// Crea un directorio si no existe
    /// - Parameter path: Path del directorio a crear
    /// - Throws: Error si falla la creación
    func createDirectory(at path: String) async throws
}
