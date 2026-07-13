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

            // Permitir cancelar el lote entre imágenes (las ya guardadas se conservan)
            try Task.checkCancellation()

            request.onLog?("[\(index + 1)/\(total)] Processing \(fileName)...", .info)

            do {
                // 1. Read image file
                let data = try Data(contentsOf: url)

                // 2. Create ImageData (width/height dummy - OCR adapter handles actual dimensions)
                let imageData = try ImageData(data: data, width: 1, height: 1)

                // 3. Run OCR
                let recognizedText = try await ocrPort.recognizeText(from: imageData)
                request.onLog?("OCR: \(recognizedText.text.count) characters recognized", .info)

                // 4. Try to generate audio if requested and TTS is available
                var audioData: Data? = nil
                var audioDuration: TimeInterval? = nil
                var audioGenerationFailed = false

                if request.generateAudio,
                   let tts = ttsPort,
                   let voiceConfig = request.voiceConfiguration,
                   let voice = request.voice {
                    do {
                        request.onLog?("Generating audio for \(fileName)...", .info)
                        let textContent = try TextContent(recognizedText.text)
                        let generatedAudio = try await tts.synthesize(
                            text: textContent,
                            voiceConfiguration: voiceConfig,
                            voice: voice
                        )
                        audioData = generatedAudio.data
                        audioDuration = generatedAudio.duration
                        print("[ProcessImageBatch] Audio generated for: \(fileName)")
                        let duration = generatedAudio.duration
                        request.onLog?(
                            String(format: "Audio generated (%d:%02d)", Int(duration) / 60, Int(duration) % 60),
                            .success
                        )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        // Audio generation failed, but continue with text + image
                        print("[ProcessImageBatch] Audio generation failed for \(fileName): \(error.localizedDescription)")
                        request.onLog?("Audio failed for \(fileName): \(error.localizedDescription)", .warning)
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
                request.onLog?("Saved entry \(saveResponse.entryNumber)", .info)

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
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Record failure and continue
                request.onLog?("Failed \(fileName): \(error.localizedDescription)", .error)
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
