import Foundation

/// Value Object que representa una imagen capturada de pantalla
/// Contiene los datos de la imagen y su path temporal
struct CapturedImage: Equatable {
    let imageData: Data
    let temporaryPath: String
    let captureDate: Date

    /// Crea una imagen capturada
    /// - Parameters:
    ///   - imageData: Datos de la imagen (PNG)
    ///   - temporaryPath: Path temporal donde se guardó la imagen
    /// - Throws: DomainError si los datos están vacíos
    init(imageData: Data, temporaryPath: String) throws {
        guard !imageData.isEmpty else {
            throw DomainError.emptyImageData
        }
        self.imageData = imageData
        self.temporaryPath = temporaryPath
        self.captureDate = Date()
    }

    /// Init para reconstitución (con fecha explícita)
    init(imageData: Data, temporaryPath: String, captureDate: Date) throws {
        guard !imageData.isEmpty else {
            throw DomainError.emptyImageData
        }
        self.imageData = imageData
        self.temporaryPath = temporaryPath
        self.captureDate = captureDate
    }
}
