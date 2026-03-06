import Foundation

/// Response DTO después de generar audio para una entrada
struct GenerateAudioForEntryResponse {
    let entryId: EntryId
    let audioPath: String
    let duration: TimeInterval
}
