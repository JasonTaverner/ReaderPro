import Foundation
import AVFoundation
import NaturalLanguage

/// Adapter para VoxCPM2 (máxima calidad, 48 kHz) vía el servidor MLX local.
/// Comparte servidor con Qwen3 (puerto 8890): el ModelManager del servidor
/// garantiza que solo hay un modelo cargado a la vez.
///
/// Modos:
/// - Sin audio de referencia → POST /synthesize con mode=voxcpm (voz por defecto)
/// - Con audio de referencia → POST /clone con model=voxcpm (clonación zero-shot)
final class VoxCPMTTSAdapter: TTSPort {

    // MARK: - Properties

    private let baseURL: URL
    private let urlSession: URLSessionProtocol
    private let healthCheckTimeout: TimeInterval = 2.0
    // 2 h: una entrada long-form de ~50k chars puede tardar >1 h en generarse
    private let synthesizeTimeout: TimeInterval = 7200.0

    /// Por encima de este tamaño se limitan los pasos de difusión a
    /// `longTextMaxSteps`: con los 10 pasos por defecto una página completa
    /// tarda >20 min en Macs con poca RAM libre.
    private let longTextCharThreshold = 1_000
    private let longTextMaxSteps = 6

    /// Códigos de idioma que acepta el servidor (SUPPORTED_LANGUAGES)
    private static let serverLanguageCodes: Set<String> = [
        "en", "es", "zh", "ja", "ko", "fr", "de", "it", "pt", "ru"
    ]

    // MARK: - Initialization

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8890")!,
        urlSession: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - TTSPort Implementation

    var provider: Voice.TTSProvider {
        .voxcpm
    }

    var isAvailable: Bool {
        get async {
            do {
                let healthURL = baseURL.appendingPathComponent("health")
                var request = URLRequest(url: healthURL)
                request.timeoutInterval = healthCheckTimeout

                let (_, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    return false
                }

                return httpResponse.statusCode == 200
            } catch {
                return false
            }
        }
    }

    func availableVoices() async -> [Voice] {
        // VoxCPM2 no tiene voces preset: voz por defecto del modelo, o clonación
        // desde audio de referencia (activar Voice Cloning con un perfil guardado)
        return [
            Voice(id: "voxcpm_default", name: "Default (VoxCPM2)", language: "multi", provider: .voxcpm, isDefault: true)
        ]
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        if let referenceURL = voiceConfiguration.referenceAudioURL {
            return try await synthesizeWithCloning(
                text: text,
                voiceConfiguration: voiceConfiguration,
                referenceAudioURL: referenceURL
            )
        }

        return try await synthesizeDefault(
            text: text,
            voiceConfiguration: voiceConfiguration
        )
    }

    // MARK: - Default Voice Synthesis

    private func synthesizeDefault(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration
    ) async throws -> AudioData {
        let synthesizeURL = baseURL.appendingPathComponent("synthesize")

        var payload: [String: Any] = [
            "text": text.value,
            "mode": "voxcpm",
            "language": detectLanguageCode(for: text.value),
        ]
        if let model = voiceConfiguration.cloneModel {
            payload["model"] = model
        }
        if let instruct = voiceConfiguration.instruct, !instruct.isEmpty {
            payload["instruct"] = instruct
        }
        if let cfg = voiceConfiguration.voxcpmCfgValue {
            payload["cfg_value"] = cfg
        }
        payload["inference_timesteps"] = effectiveSteps(
            for: text.value,
            requested: voiceConfiguration.voxcpmSteps
        )

        var request = URLRequest(url: synthesizeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = synthesizeTimeout

        print("[VoxCPMTTSAdapter] Synthesizing \(text.value.count) chars (default voice)")

        let (data, response) = try await performRequest(request)
        return try parseAudioResponse(data: data, response: response)
    }

    // MARK: - Voice Cloning

    private func synthesizeWithCloning(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        referenceAudioURL: URL
    ) async throws -> AudioData {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("clone"))
        request.httpMethod = "POST"
        request.httpBody = try buildCloneBody(
            text: text,
            voiceConfiguration: voiceConfiguration,
            referenceAudioURL: referenceAudioURL,
            boundary: boundary
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        print("[VoxCPMTTSAdapter] Cloning voice from: \(referenceAudioURL.lastPathComponent)")

        let (data, response) = try await performRequest(request)
        return try parseAudioResponse(data: data, response: response)
    }

    /// Cuerpo multipart común a /clone (síncrono) y /clone_async (incremental)
    private func buildCloneBody(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        referenceAudioURL: URL,
        boundary: String
    ) throws -> Data {
        let audioData: Data
        do {
            audioData = try Data(contentsOf: referenceAudioURL)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Cannot read reference audio: \(error.localizedDescription)")
        }

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Audio file field
        let filename = referenceAudioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        appendField("text", text.value)
        appendField("language", detectLanguageCode(for: text.value))
        appendField("model", voiceConfiguration.cloneModel ?? "voxcpm")

        if let refText = voiceConfiguration.referenceText, !refText.isEmpty {
            appendField("ref_text", refText)
        }
        // Instrucciones de estilo (p. ej. "Habla pausadamente, con tono calmado")
        if let instruct = voiceConfiguration.instruct, !instruct.isEmpty {
            appendField("accent_instruct", instruct)
        }
        if let cfg = voiceConfiguration.voxcpmCfgValue {
            appendField("cfg_value", "\(cfg)")
        }
        appendField(
            "inference_timesteps",
            "\(effectiveSteps(for: text.value, requested: voiceConfiguration.voxcpmSteps))"
        )
        if voiceConfiguration.voxcpmContinuation {
            appendField("continuation", "true")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    // MARK: - Incremental Clone Job (reproducción por segmentos)

    /// Estado de un job de clonación asíncrono en el servidor
    struct CloneJobStatus {
        let jobId: String
        let state: String        // running | done | error | cancelled
        let segmentsDone: Int
        let segmentsTotal: Int
        let error: String?

        var isTerminal: Bool { state != "running" }
    }

    /// Arranca una clonación asíncrona (POST /clone_async).
    /// Devuelve nil si el servidor no soporta el endpoint (fallback a /clone).
    func startCloneJob(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        referenceAudioURL: URL
    ) async throws -> CloneJobStatus? {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("clone_async"))
        request.httpMethod = "POST"
        request.httpBody = try buildCloneBody(
            text: text,
            voiceConfiguration: voiceConfiguration,
            referenceAudioURL: referenceAudioURL,
            boundary: boundary
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let (data, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from VoxCPM server")
        }
        if httpResponse.statusCode == 404 {
            // Servidor antiguo sin /clone_async
            return nil
        }
        guard httpResponse.statusCode == 202, let status = parseJobStatus(data) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.ttsRequestFailed("VoxCPM clone_async error (\(httpResponse.statusCode)): \(serverMessage)")
        }
        print("[VoxCPMTTSAdapter] Clone job started: \(status.jobId) (~\(status.segmentsTotal) segments)")
        return status
    }

    /// Estado del job (nil si la petición falla — best effort para el poll).
    func fetchCloneJobStatus(jobId: String) async -> CloneJobStatus? {
        var request = URLRequest(url: baseURL.appendingPathComponent("clone_status/\(jobId)"))
        request.timeoutInterval = 5.0
        guard let (data, response) = try? await urlSession.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        return parseJobStatus(data)
    }

    /// Descarga el WAV completo de un job terminado.
    func fetchCloneResult(jobId: String) async throws -> AudioData {
        var request = URLRequest(url: baseURL.appendingPathComponent("clone_result/\(jobId)"))
        request.timeoutInterval = 120.0
        let (data, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.ttsRequestFailed("Clone result not available: \(serverMessage)")
        }
        let duration = try getDuration(of: data)
        return try AudioData(data: data, duration: duration)
    }

    private func parseJobStatus(_ data: Data) -> CloneJobStatus? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jobId = json["job_id"] as? String else { return nil }
        return CloneJobStatus(
            jobId: jobId,
            state: json["state"] as? String ?? "running",
            segmentsDone: json["segments_done"] as? Int ?? 0,
            segmentsTotal: json["segments_total"] as? Int ?? 0,
            error: json["error"] as? String
        )
    }

    // MARK: - Helpers

    private func parseAudioResponse(data: Data, response: URLResponse) throws -> AudioData {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from VoxCPM server")
        }

        guard httpResponse.statusCode == 200 else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.ttsRequestFailed("VoxCPM server error (\(httpResponse.statusCode)): \(serverMessage)")
        }

        let duration = try getDuration(of: data)
        return try AudioData(data: data, duration: duration)
    }

    /// Pasos de difusión efectivos: respeta lo pedido salvo en textos largos,
    /// donde se limitan para que la generación no se dispare a >15-20 min.
    private func effectiveSteps(for text: String, requested: Int?) -> Int {
        let steps = requested ?? 10
        guard text.count > longTextCharThreshold, steps > longTextMaxSteps else {
            return steps
        }
        print("[VoxCPMTTSAdapter] Long text (\(text.count) chars): capping diffusion steps \(steps) → \(longTextMaxSteps)")
        return longTextMaxSteps
    }

    /// Detecta el idioma del texto con NaturalLanguage y lo mapea a un código
    /// que el servidor entienda. Antes se enviaba "auto" y el servidor lo
    /// interpretaba como inglés para las familias que sí usan lang_code.
    private func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(1_000)))
        guard let language = recognizer.dominantLanguage else { return "auto" }

        let code: String
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            code = "zh"
        default:
            code = language.rawValue
        }
        return Self.serverLanguageCodes.contains(code) ? code : "auto"
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw InfrastructureError.ttsRequestFailed("VoxCPM request failed: \(error.localizedDescription)")
        }
    }

    private func getDuration(of audioData: Data) throws -> TimeInterval {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try audioData.write(to: tempURL)

        do {
            let audioFile = try AVAudioFile(forReading: tempURL)
            let frameCount = audioFile.length
            let sampleRate = audioFile.processingFormat.sampleRate
            return Double(frameCount) / sampleRate
        } catch {
            // Fallback: estimate based on WAV size (48kHz, 16-bit, mono = 96000 bytes/sec)
            let bytesPerSecond: Double = 96_000
            return max(Double(audioData.count - 44) / bytesPerSecond, 0.1)
        }
    }
}
