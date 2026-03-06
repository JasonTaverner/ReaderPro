import Foundation

/// Response DTO después de guardar una entrada de audio
struct SaveAudioEntryResponse {
    let entryId: String
    let entryNumber: Int  // 1, 2, 3... (para nombres de archivos 001, 002, 003...)
    let textPath: String
    let audioPath: String
    let imagePath: String?

    init(
        entryId: String,
        entryNumber: Int,
        textPath: String,
        audioPath: String,
        imagePath: String?
    ) {
        self.entryId = entryId
        self.entryNumber = entryNumber
        self.textPath = textPath
        self.audioPath = audioPath
        self.imagePath = imagePath
    }
}
