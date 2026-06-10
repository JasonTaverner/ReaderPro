import Foundation
import AVFoundation

/// Adapter para Chatterbox Multilingual (500M, MIT) vía el servidor MLX local.
/// Comparte servidor con Qwen3/VoxCPM2 (puerto 8890): el ModelManager garantiza
/// un solo modelo cargado a la vez.
///
/// Velocidad ~tiempo real en M4. La voz por defecto es floja: el flujo
/// recomendado es SIEMPRE clonación con un perfil guardado (acento castellano
/// verificado clonando referencias es-ES).
final class ChatterboxTTSAdapter: TTSPort {

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
        .chatterbox
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
        return [
            Voice(id: "chatterbox_default", name: "Default (Chatterbox)", language: "multi", provider: .chatterbox, isDefault: true)
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
            "mode": "chatterbox",
            "language": voiceConfiguration.chatterboxLanguage ?? "es",
        ]
        if let exaggeration = voiceConfiguration.chatterboxExaggeration {
            payload["exaggeration"] = exaggeration
        }
        if let cfgWeight = voiceConfiguration.chatterboxCfgWeight {
            payload["cfg_weight"] = cfgWeight
        }

        var request = URLRequest(url: synthesizeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = synthesizeTimeout

        print("[ChatterboxTTSAdapter] Synthesizing \(text.value.count) chars (default voice)")

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

        let filename = referenceAudioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        appendField("text", text.value)
        appendField("language", voiceConfiguration.chatterboxLanguage ?? "es")
        appendField("model", "chatterbox")

        if let exaggeration = voiceConfiguration.chatterboxExaggeration {
            appendField("exaggeration", "\(exaggeration)")
        }
        if let cfgWeight = voiceConfiguration.chatterboxCfgWeight {
            appendField("cfg_weight", "\(cfgWeight)")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("[ChatterboxTTSAdapter] Cloning voice from: \(filename)")

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
            throw InfrastructureError.ttsRequestFailed("Invalid response from Chatterbox server")
        }

        guard httpResponse.statusCode == 200 else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.ttsRequestFailed("Chatterbox server error (\(httpResponse.statusCode)): \(serverMessage)")
        }

        let duration = try getDuration(of: data)
        return try AudioData(data: data, duration: duration)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Chatterbox request failed: \(error.localizedDescription)")
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
            // Fallback: estimate based on WAV size (24kHz, 16-bit, mono = 48000 bytes/sec)
            let bytesPerSecond: Double = 48_000
            return max(Double(audioData.count - 44) / bytesPerSecond, 0.1)
        }
    }
}
