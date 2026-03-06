import Foundation

/// Saved cloned voice profile containing a reference audio + transcript pair.
/// This is NOT a trained model - it's a reference that gets sent to the TTS server
/// on every generation request (ICL mode).
struct ClonedVoiceProfile: Equatable, Identifiable {
    let id: String
    let name: String
    let audioFileName: String
    let referenceText: String
    let audioDuration: TimeInterval
    let createdAt: Date
}
