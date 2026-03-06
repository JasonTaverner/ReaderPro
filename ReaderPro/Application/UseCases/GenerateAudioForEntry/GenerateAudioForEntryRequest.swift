import Foundation

/// Request DTO para generar audio de una entrada existente
struct GenerateAudioForEntryRequest {
    let projectId: Identifier<Project>
    let entryId: EntryId
    let voiceConfiguration: VoiceConfiguration
    let voice: Voice

    init(
        projectId: Identifier<Project>,
        entryId: EntryId,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) {
        self.projectId = projectId
        self.entryId = entryId
        self.voiceConfiguration = voiceConfiguration
        self.voice = voice
    }
}
