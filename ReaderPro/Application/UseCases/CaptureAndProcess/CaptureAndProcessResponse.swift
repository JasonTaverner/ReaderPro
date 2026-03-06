import Foundation

/// Response DTO después de capturar, OCR y guardar
struct CaptureAndProcessResponse {
    let recognizedText: String
    let confidence: Double
    let entryId: String
    let entryNumber: Int
    let imagePath: String?
    let audioPath: String?  // nil si no se generó audio
}
