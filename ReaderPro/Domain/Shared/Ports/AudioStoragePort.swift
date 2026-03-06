import Foundation

/// Port para almacenamiento de archivos de audio
/// Define la interfaz que deben implementar los adaptadores de storage
/// (FileSystemStorageAdapter, CloudStorageAdapter, etc.)
protocol AudioStoragePort {
    /// Guarda datos de audio en el sistema de archivos
    /// - Parameters:
    ///   - audioData: Los datos de audio a guardar
    ///   - folderName: Nombre de la carpeta del proyecto en disco
    ///   - entryNumber: Número secuencial para el archivo (001, 002...). Si nil, auto-detecta el siguiente.
    /// - Returns: Path relativo al archivo guardado
    /// - Throws: Error si falla el guardado
    func save(audioData: AudioData, folderName: String, entryNumber: Int?) async throws -> String

    /// Carga datos de audio desde un path
    /// - Parameter path: Path al archivo de audio
    /// - Returns: Los datos de audio cargados
    /// - Throws: Error si el archivo no existe o no se puede leer
    func load(path: String) async throws -> AudioData

    /// Elimina un archivo de audio
    /// - Parameter path: Path al archivo a eliminar
    /// - Throws: Error si el archivo no existe o no se puede eliminar
    func delete(path: String) async throws

    /// Exporta audio a un formato y calidad específicos
    /// - Parameters:
    ///   - path: Path al archivo de audio original
    ///   - format: Formato de salida deseado
    ///   - quality: Calidad de audio deseada
    /// - Returns: Los datos del audio exportado (listo para guardar)
    /// - Throws: Error si falla la conversión
    func export(path: String, format: AudioFormat, quality: AudioQuality) async throws -> Data

    /// Copia un archivo de audio a una nueva ubicación
    /// - Parameters:
    ///   - sourcePath: Path del archivo origen
    ///   - destinationPath: Path del archivo destino
    /// - Throws: Error si falla la copia
    func copy(from sourcePath: String, to destinationPath: String) async throws

    /// Mueve un archivo de audio a una nueva ubicación
    /// - Parameters:
    ///   - sourcePath: Path del archivo origen
    ///   - destinationPath: Path del archivo destino
    /// - Throws: Error si falla el movimiento
    func move(from sourcePath: String, to destinationPath: String) async throws

    /// Verifica si existe un archivo en el path especificado
    /// - Parameter path: Path a verificar
    /// - Returns: true si existe, false si no
    func exists(path: String) async -> Bool

    /// Obtiene el tamaño de un archivo de audio
    /// - Parameter path: Path al archivo
    /// - Returns: Tamaño en bytes
    /// - Throws: Error si el archivo no existe
    func getSize(path: String) async throws -> Int

    /// Obtiene el directorio base donde se almacenan los audios
    /// - Returns: Path al directorio base
    var baseDirectory: String { get }

    /// Genera un path único para un nuevo archivo de audio
    /// - Parameters:
    ///   - folderName: Nombre de la carpeta del proyecto
    ///   - format: Formato del archivo
    /// - Returns: Path único generado
    func generateUniquePath(folderName: String, format: AudioFormat) async -> String
}
