import Foundation

/// Protocol for ProcessTextBatchUseCase
protocol ProcessTextBatchUseCaseProtocol {
    func execute(_ request: ProcessTextBatchRequest) async throws -> ProcessTextBatchResponse
}

/// Use case to process a batch of text fragments into AudioEntries
/// Splits text by paragraphs, sentences, or word count and creates entries for each
final class ProcessTextBatchUseCase: ProcessTextBatchUseCaseProtocol {

    // MARK: - Dependencies

    private let projectRepository: ProjectRepositoryPort
    private let ttsPort: TTSPort?
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol

    // MARK: - Common abbreviations to avoid splitting

    private static let abbreviations = ["Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.", "vs.", "etc.", "i.e.", "e.g."]

    // MARK: - Initialization

    init(
        projectRepository: ProjectRepositoryPort,
        ttsPort: TTSPort? = nil,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    ) {
        self.projectRepository = projectRepository
        self.ttsPort = ttsPort
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
    }

    // MARK: - Execute

    func execute(_ request: ProcessTextBatchRequest) async throws -> ProcessTextBatchResponse {
        // 1. Validate text is not empty
        let trimmedText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ApplicationError.textProcessingFailed("Text is empty")
        }

        // 2. Verify project exists
        guard let _ = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }

        // 3. Split text into fragments
        let fragments = splitText(trimmedText, mode: request.splitMode)

        guard !fragments.isEmpty else {
            throw ApplicationError.textProcessingFailed("No valid text fragments found")
        }

        // 4. Create entry for each fragment
        var entriesCreated = 0
        var entriesWithAudio = 0
        var entriesWithoutAudio = 0
        var errors: [String] = []
        var fragmentPreviews: [String] = []

        for (index, fragment) in fragments.enumerated() {
            do {
                // Try to generate audio if requested
                var audioData: Data? = nil
                var audioDuration: TimeInterval? = nil

                if request.generateAudio,
                   let tts = ttsPort,
                   let voiceConfig = request.voiceConfiguration,
                   let voice = request.voice {
                    do {
                        let textContent = try TextContent(fragment)
                        let generatedAudio = try await tts.synthesize(
                            text: textContent,
                            voiceConfiguration: voiceConfig,
                            voice: voice
                        )
                        audioData = generatedAudio.data
                        audioDuration = generatedAudio.duration
                    } catch {
                        print("[ProcessTextBatch] Audio generation failed for fragment \(index + 1): \(error.localizedDescription)")
                    }
                }

                let entryRequest = SaveAudioEntryRequest(
                    projectId: request.projectId,
                    text: fragment,
                    audioData: audioData,
                    audioDuration: audioDuration
                )

                _ = try await saveAudioEntryUseCase.execute(entryRequest)
                entriesCreated += 1
                
                if audioData != nil {
                    entriesWithAudio += 1
                } else {
                    entriesWithoutAudio += 1
                }
                
                fragmentPreviews.append(String(fragment.prefix(100)))

                // Report progress
                request.onProgress?(index + 1, fragments.count)

            } catch {
                errors.append("Fragment \(index + 1): \(error.localizedDescription)")
            }
        }

        // 5. Return response
        return ProcessTextBatchResponse(
            projectId: request.projectId,
            entriesCreated: entriesCreated,
            entriesWithAudio: entriesWithAudio,
            entriesWithoutAudio: entriesWithoutAudio,
            fragments: fragmentPreviews,
            failureCount: errors.count,
            errors: errors
        )
    }

    // MARK: - Text Splitting

    private func splitText(_ text: String, mode: TextSplitMode) -> [String] {
        switch mode {
        case .paragraph:
            return splitByParagraph(text)
        case .sentence:
            return splitBySentence(text)
        case .words(let count):
            return splitByWords(text, count: count)
        }
    }

    /// Split text by double line breaks (paragraphs)
    private func splitByParagraph(_ text: String) -> [String] {
        // Split by double newlines (with optional whitespace between)
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs
    }

    /// Split text by sentence endings (., !, ?)
    private func splitBySentence(_ text: String) -> [String] {
        var sentences: [String] = []
        var currentSentence = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]
            currentSentence.append(char)

            // Check for sentence ending
            if char == "." || char == "!" || char == "?" {
                // Check if this is an abbreviation
                let trimmed = currentSentence.trimmingCharacters(in: .whitespaces)
                let isAbbreviation = Self.abbreviations.contains { trimmed.hasSuffix($0) }

                if !isAbbreviation {
                    // This is a real sentence ending
                    let sentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty {
                        sentences.append(sentence)
                    }
                    currentSentence = ""
                }
            }

            i = text.index(after: i)
        }

        // Add remaining text as last sentence
        let remaining = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }

        return sentences
    }

    /// Split text every N words
    private func splitByWords(_ text: String, count: Int) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        var fragments: [String] = []
        var currentFragment: [Substring] = []

        for word in words {
            currentFragment.append(word)

            if currentFragment.count >= count {
                let fragment = currentFragment.joined(separator: " ")
                fragments.append(fragment)
                currentFragment = []
            }
        }

        // Add remaining words
        if !currentFragment.isEmpty {
            let fragment = currentFragment.joined(separator: " ")
            fragments.append(fragment)
        }

        return fragments
    }
}

// MARK: - Text Splitting Utility (for preview)

extension ProcessTextBatchUseCase {

    /// Preview how text will be split without creating entries
    /// Useful for showing a preview in the UI before processing
    static func previewSplit(text: String, mode: TextSplitMode) -> [String] {
        let instance = ProcessTextBatchUseCase(
            projectRepository: DummyProjectRepository(),
            saveAudioEntryUseCase: DummySaveAudioEntryUseCase()
        )
        return instance.splitText(text, mode: mode)
    }
}

// MARK: - Dummy implementations for preview

private final class DummyProjectRepository: ProjectRepositoryPort {
    var baseDirectory: String { "" }
    func save(_ project: Project) async throws {}
    func findById(_ id: Identifier<Project>) async throws -> Project? { nil }
    func findByName(_ name: String) async throws -> Project? { nil }
    func findAll() async throws -> [Project] { [] }
    func delete(_ id: Identifier<Project>) async throws {}
    func deleteDirectory(at path: String) async throws {}
    func search(query: String) async throws -> [Project] { [] }
    func findByStatus(_ status: ProjectStatus) async throws -> [Project] { [] }
    func findCreatedAfter(_ date: Date) async throws -> [Project] { [] }
}

private final class DummySaveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol {
    func execute(_ request: SaveAudioEntryRequest) async throws -> SaveAudioEntryResponse {
        SaveAudioEntryResponse(
            entryId: UUID().uuidString,
            entryNumber: 0,
            textPath: "",
            audioPath: "",
            imagePath: nil
        )
    }
}
