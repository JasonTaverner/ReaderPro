import Foundation
import AVFoundation

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
        ]
        if let instruct = voiceConfiguration.instruct, !instruct.isEmpty {
            payload["instruct"] = instruct
        }
        if let cfg = voiceConfiguration.voxcpmCfgValue {
            payload["cfg_value"] = cfg
        }
        if let steps = voiceConfiguration.voxcpmSteps {
            payload["inference_timesteps"] = steps
        }

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
        let cloneURL = baseURL.appendingPathComponent("clone")

        let audioData: Data
        do {
            audioData = try Data(contentsOf: referenceAudioURL)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Cannot read reference audio: \(error.localizedDescription)")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
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
        appendField("language", "auto")
        appendField("model", "voxcpm")

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
        if let steps = voiceConfiguration.voxcpmSteps {
            appendField("inference_timesteps", "\(steps)")
        }
        if voiceConfiguration.voxcpmContinuation {
            appendField("continuation", "true")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("[VoxCPMTTSAdapter] Cloning voice from: \(filename)")

        var request = URLRequest(url: cloneURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        let (data, response) = try await performRequest(request)
        return try parseAudioResponse(data: data, response: response)
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
