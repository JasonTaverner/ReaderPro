import Foundation

/// Caso de uso para procesar un lote de imágenes con OCR y crear AudioEntries
/// Opcionalmente genera audio con TTS (Kokoro) para cada imagen procesada
final class ProcessImageBatchUseCase {

    // MARK: - Dependencies

    private let ocrPort: OCRPort
    private let ttsPort: TTSPort?
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol

    // MARK: - Initialization

    init(
        ocrPort: OCRPort,
        ttsPort: TTSPort? = nil,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    ) {
        self.ocrPort = ocrPort
        self.ttsPort = ttsPort
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
    }

    // MARK: - Execution

    func execute(_ request: ProcessImageBatchRequest) async throws -> ProcessImageBatchResponse {
        let imageURLs = request.imageURLs
        let total = imageURLs.count

        var successfulEntries: [ProcessImageBatchResponse.ProcessedEntry] = []
        var failedImages: [ProcessImageBatchResponse.FailedImage] = []

        for (index, url) in imageURLs.enumerated() {
            let fileName = url.lastPathComponent

            do {
                // 1. Read image file
                let data = try Data(contentsOf: url)

                // 2. Create ImageData (width/height dummy - OCR adapter handles actual dimensions)
                let imageData = try ImageData(data: data, width: 1, height: 1)

                // 3. Run OCR
                let recognizedText = try await ocrPort.recognizeText(from: imageData)

                // 4. Try to generate audio if requested and TTS is available
                var audioData: Data? = nil
                var audioDuration: TimeInterval? = nil
                var audioGenerationFailed = false

                if request.generateAudio,
                   let tts = ttsPort,
                   let voiceConfig = request.voiceConfiguration,
                   let voice = request.voice {
                    do {
                        let textContent = try TextContent(recognizedText.text)
                        let generatedAudio = try await tts.synthesize(
                            text: textContent,
                            voiceConfiguration: voiceConfig,
                            voice: voice
                        )
                        audioData = generatedAudio.data
                        audioDuration = generatedAudio.duration
                        print("[ProcessImageBatch] Audio generated for: \(fileName)")
                    } catch {
                        // Audio generation failed, but continue with text + image
                        print("[ProcessImageBatch] Audio generation failed for \(fileName): \(error.localizedDescription)")
                        audioGenerationFailed = true
                    }
                }

                // 5. Save as AudioEntry (with or without audio)
                let saveRequest = SaveAudioEntryRequest(
                    projectId: request.projectId,
                    text: recognizedText.text,
                    audioData: audioData,
                    audioDuration: audioDuration,
                    imagePath: url.path
                )
                let saveResponse = try await saveAudioEntryUseCase.execute(saveRequest)

                // 6. Record success
                successfulEntries.append(
                    ProcessImageBatchResponse.ProcessedEntry(
                        entryId: saveResponse.entryId,
                        entryNumber: saveResponse.entryNumber,
                        recognizedText: recognizedText.text,
                        sourceFileName: fileName,
                        hasAudio: audioData != nil,
                        audioGenerationFailed: audioGenerationFailed
                    )
                )
            } catch {
                // Record failure and continue
                failedImages.append(
                    ProcessImageBatchResponse.FailedImage(
                        fileName: fileName,
                        reason: error.localizedDescription
                    )
                )
            }

            // 7. Report progress
            request.onProgress?(index + 1, total)
        }

        return ProcessImageBatchResponse(
            successfulEntries: successfulEntries,
            failedImages: failedImages,
            totalImages: total
        )
    }
}
