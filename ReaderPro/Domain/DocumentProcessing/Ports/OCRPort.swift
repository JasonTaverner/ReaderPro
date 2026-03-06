import Foundation

/// Port para servicios de OCR (Optical Character Recognition)
/// Define la interfaz que deben implementar los adaptadores de OCR
/// (VisionOCRAdapter, TesseractAdapter, etc.)
protocol OCRPort {
    /// Indica si el servicio OCR está disponible
    var isAvailable: Bool { get async }

    /// Extrae texto de una imagen
    /// - Parameter imageData: Los datos de la imagen
    /// - Returns: El texto reconocido con metadatos
    /// - Throws: Error si falla el reconocimiento
    func recognizeText(from imageData: ImageData) async throws -> RecognizedText

    /// Extrae texto de un archivo PDF (página específica)
    /// - Parameters:
    ///   - pdfPath: Path al archivo PDF
    ///   - pageNumber: Número de página (base 1)
    /// - Returns: El texto reconocido
    /// - Throws: Error si falla el reconocimiento o la página no existe
    func recognizeText(from pdfPath: String, pageNumber: Int) async throws -> RecognizedText

    /// Extrae texto de todas las páginas de un PDF
    /// - Parameter pdfPath: Path al archivo PDF
    /// - Returns: Lista de texto reconocido por página
    /// - Throws: Error si falla el reconocimiento
    func recognizeText(from pdfPath: String) async throws -> [RecognizedText]

    /// Captura y extrae texto de una región de la pantalla
    /// - Parameter screenRegion: Región de la pantalla (x, y, width, height)
    /// - Returns: El texto reconocido
    /// - Throws: Error si falla la captura o reconocimiento
    func recognizeTextFromScreen(region: ScreenRegion?) async throws -> RecognizedText

    /// Idiomas soportados por el OCR
    var supportedLanguages: [String] { get async }
}

/// Representa una región rectangular de la pantalla
struct ScreenRegion: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(x: Int, y: Int, width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw DomainError.invalidImageDimensions
        }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Región que representa toda la pantalla (nil significa capturar todo)
    static var fullScreen: ScreenRegion? { nil }
}
