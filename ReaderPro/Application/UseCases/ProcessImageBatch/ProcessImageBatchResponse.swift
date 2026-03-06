import Foundation

/// Response DTO después de procesar un lote de imágenes con OCR
struct ProcessImageBatchResponse {
    let successfulEntries: [ProcessedEntry]
    let failedImages: [FailedImage]
    let totalImages: Int

    var successCount: Int { successfulEntries.count }
    var failureCount: Int { failedImages.count }
    var entriesWithAudio: Int { successfulEntries.filter { $0.hasAudio }.count }
    var entriesWithoutAudio: Int { successfulEntries.filter { !$0.hasAudio }.count }

    struct ProcessedEntry {
        let entryId: String
        let entryNumber: Int
        let recognizedText: String
        let sourceFileName: String
        let hasAudio: Bool
        let audioGenerationFailed: Bool

        init(
            entryId: String,
            entryNumber: Int,
            recognizedText: String,
            sourceFileName: String,
            hasAudio: Bool = false,
            audioGenerationFailed: Bool = false
        ) {
            self.entryId = entryId
            self.entryNumber = entryNumber
            self.recognizedText = recognizedText
            self.sourceFileName = sourceFileName
            self.hasAudio = hasAudio
            self.audioGenerationFailed = audioGenerationFailed
        }
    }

    struct FailedImage {
        let fileName: String
        let reason: String
    }
}
