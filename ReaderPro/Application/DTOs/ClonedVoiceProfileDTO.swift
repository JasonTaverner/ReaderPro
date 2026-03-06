import Foundation

/// DTO for transferring cloned voice profile data to the UI layer
struct ClonedVoiceProfileDTO: Identifiable, Equatable {
    let id: String
    let name: String
    let referenceText: String
    let audioDuration: TimeInterval
    let createdAt: Date

    var formattedDuration: String {
        String(format: "%.1fs", audioDuration)
    }

    init(from profile: ClonedVoiceProfile) {
        self.id = profile.id
        self.name = profile.name
        self.referenceText = profile.referenceText
        self.audioDuration = profile.audioDuration
        self.createdAt = profile.createdAt
    }
}
