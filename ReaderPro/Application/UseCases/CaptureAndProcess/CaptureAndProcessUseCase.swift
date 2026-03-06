import Foundation

/// Use Case que orquesta: Captura de pantalla → OCR → Guardar AudioEntry → (Opcional) Generar Audio
/// Sigue el flujo: usuario selecciona región → Vision extrae texto → se guarda como entry
final class CaptureAndProcessUseCase: CaptureAndProcessUseCaseProtocol {

    // MARK: - Dependencies

    private let screenCapturePort: ScreenCapturePort
    private let ocrPort: OCRPort
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    private let ttsPort: TTSPort

    // MARK: - Initialization

    init(
        screenCapturePort: ScreenCapturePort,
        ocrPort: OCRPort,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol,
        ttsPort: TTSPort
    ) {
        self.screenCapturePort = screenCapturePort
        self.ocrPort = ocrPort
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
        self.ttsPort = ttsPort
    }

    // MARK: - Execute

    func execute(_ request: CaptureAndProcessRequest) async throws -> CaptureAndProcessResponse {
        // 1. Capturar pantalla (interactivo)
        let capturedImage = try await screenCapturePort.captureInteractive()

        // 2. Ejecutar OCR en la imagen capturada
        // Width/height are metadata-only; Vision reads actual dimensions from PNG data
        let imageData = try ImageData(
            data: capturedImage.imageData,
            width: 1,
            height: 1
        )
        let recognizedText = try await ocrPort.recognizeText(from: imageData)

        // 3. Si generateAudio, sintetizar audio primero
        var audioData: Data? = nil
        var audioDuration: TimeInterval? = nil

        if request.generateAudio {
            let textContent = try TextContent(recognizedText.text)
            let voiceConfig = VoiceConfiguration(
                voiceId: "",
                speed: .normal
            )
            let defaultVoice = (await ttsPort.availableVoices()).first ?? Voice(
                id: "default",
                name: "Default",
                language: "en",
                provider: .native,
                isDefault: true
            )
            let result = try await ttsPort.synthesize(
                text: textContent,
                voiceConfiguration: voiceConfig,
                voice: defaultVoice
            )
            audioData = result.data
            audioDuration = result.duration
        }

        // 4. Guardar como AudioEntry
        let saveRequest = SaveAudioEntryRequest(
            projectId: request.projectId,
            text: recognizedText.text,
            audioData: audioData,
            audioDuration: audioDuration,
            imagePath: capturedImage.temporaryPath
        )
        let saveResponse = try await saveAudioEntryUseCase.execute(saveRequest)

        // 5. Retornar respuesta
        return CaptureAndProcessResponse(
            recognizedText: recognizedText.text,
            confidence: recognizedText.confidence,
            entryId: saveResponse.entryId,
            entryNumber: saveResponse.entryNumber,
            imagePath: saveResponse.imagePath,
            audioPath: saveResponse.audioPath
        )
    }
}
