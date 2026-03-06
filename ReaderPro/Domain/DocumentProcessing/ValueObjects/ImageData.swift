import Foundation

/// Value Object que representa datos de imagen
/// Usado para pasar imágenes a servicios de OCR y procesamiento
struct ImageData: Equatable {
    let data: Data
    let width: Int
    let height: Int

    /// Crea datos de imagen
    /// - Parameters:
    ///   - data: Los bytes de la imagen
    ///   - width: Ancho en píxeles
    ///   - height: Alto en píxeles
    /// - Throws: DomainError si los valores son inválidos
    init(data: Data, width: Int, height: Int) throws {
        guard !data.isEmpty else {
            throw DomainError.emptyImageData
        }
        guard width > 0 && height > 0 else {
            throw DomainError.invalidImageDimensions
        }
        self.data = data
        self.width = width
        self.height = height
    }

    /// Tamaño de la imagen en bytes
    var sizeInBytes: Int {
        data.count
    }

    /// Tamaño en KB
    var sizeInKB: Double {
        Double(sizeInBytes) / 1024.0
    }

    /// Tamaño en MB
    var sizeInMB: Double {
        Double(sizeInBytes) / 1_048_576.0
    }

    /// Aspect ratio (ancho/alto)
    var aspectRatio: Double {
        Double(width) / Double(height)
    }
}
