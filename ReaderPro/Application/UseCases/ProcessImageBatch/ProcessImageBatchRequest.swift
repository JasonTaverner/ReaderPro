import Foundation

/// Request DTO para procesar un lote de imágenes con OCR
struct ProcessImageBatchRequest {
    let projectId: Identifier<Project>
    let imageURLs: [URL]
    let generateAudio: Bool
    let voiceConfiguration: VoiceConfiguration?
    let voice: Voice?
    let onProgress: ((Int, Int) -> Void)?

    init(
        projectId: Identifier<Project>,
        imageURLs: [URL],
        generateAudio: Bool = true,
        voiceConfiguration: VoiceConfiguration? = nil,
        voice: Voice? = nil,
        onProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.projectId = projectId
        self.imageURLs = imageURLs
        self.generateAudio = generateAudio
        self.voiceConfiguration = voiceConfiguration
        self.voice = voice
        self.onProgress = onProgress
    }
}
