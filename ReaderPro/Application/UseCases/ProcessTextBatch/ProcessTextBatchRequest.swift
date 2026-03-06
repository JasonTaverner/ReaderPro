import Foundation

/// How to split the text into fragments
enum TextSplitMode: Equatable {
    /// Split by double line breaks (paragraphs)
    case paragraph
    /// Split by sentence endings (., !, ?)
    case sentence
    /// Split every N words
    case words(count: Int)

    var displayName: String {
        switch self {
        case .paragraph:
            return "By Paragraphs"
        case .sentence:
            return "By Sentences"
        case .words(let count):
            return "Every \(count) words"
        }
    }
}

/// Request for ProcessTextBatchUseCase
struct ProcessTextBatchRequest {
    /// Project ID to add entries to
    let projectId: Identifier<Project>

    /// The text to split and process
    let text: String

    /// How to split the text
    let splitMode: TextSplitMode

    /// Whether to generate audio for each fragment
    let generateAudio: Bool

    /// Voice configuration (required if generateAudio is true)
    let voiceConfiguration: VoiceConfiguration?

    /// Selected voice (required if generateAudio is true)
    let voice: Voice?

    /// Optional progress callback (current, total)
    let onProgress: ((Int, Int) -> Void)?

    init(
        projectId: Identifier<Project>,
        text: String,
        splitMode: TextSplitMode,
        generateAudio: Bool = false,
        voiceConfiguration: VoiceConfiguration? = nil,
        voice: Voice? = nil,
        onProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.projectId = projectId
        self.text = text
        self.splitMode = splitMode
        self.generateAudio = generateAudio
        self.voiceConfiguration = voiceConfiguration
        self.voice = voice
        self.onProgress = onProgress
    }
}
