import Foundation
import AVFoundation

/// Adapter para Supertonic v3 (ONNX, ~4x tiempo real) vía el servidor MLX local.
/// 10 voces preset (M1-M5, F1-F5), 31 idiomas, tags de expresión (<laugh>, <breath>,
/// <sigh>) escritos en el texto. Sin clonación (las voces personalizadas son de pago
/// en la plataforma de Supertone). A diferencia del resto de modelos, SÍ aplica la
/// velocidad del proyecto en generación.
final class SupertonicTTSAdapter: TTSPort {

    // MARK: - Properties

    private let baseURL: URL
    private let urlSession: URLSessionProtocol
    private let healthCheckTimeout: TimeInterval = 2.0
    // 2 h: una entrada long-form de ~50k chars (el SDK trocea internamente)
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
        .supertonic
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
        // 10 voces preset del paquete open-weight (compartidas entre los 31 idiomas)
        let presets: [(id: String, name: String)] = [
            ("M1", "Male 1"), ("M2", "Male 2"), ("M3", "Male 3"), ("M4", "Male 4"), ("M5", "Male 5"),
            ("F1", "Female 1"), ("F2", "Female 2"), ("F3", "Female 3"), ("F4", "Female 4"), ("F5", "Female 5"),
        ]
        return presets.map { preset in
            Voice(
                id: preset.id,
                name: "\(preset.name) (\(preset.id))",
                language: "multi",
                provider: .supertonic,
                isDefault: preset.id == "M1"
            )
        }
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        let synthesizeURL = baseURL.appendingPathComponent("synthesize")

        var payload: [String: Any] = [
            "text": text.value,
            "mode": "supertonic",
            "speaker": voiceConfiguration.voiceId,
            "language": voiceConfiguration.supertonicLanguage ?? "es",
            "speed": voiceConfiguration.speed.value,
        ]
        var request = URLRequest(url: synthesizeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = synthesizeTimeout

        print("[SupertonicTTSAdapter] Synthesizing \(text.value.count) chars (voice \(voiceConfiguration.voiceId))")

        let (data, response) = try await performRequest(request)
        return try parseAudioResponse(data: data, response: response)
    }

    // MARK: - Helpers

    private func parseAudioResponse(data: Data, response: URLResponse) throws -> AudioData {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from Supertonic server")
        }

        guard httpResponse.statusCode == 200 else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.ttsRequestFailed("Supertonic server error (\(httpResponse.statusCode)): \(serverMessage)")
        }

        let duration = try getDuration(of: data)
        return try AudioData(data: data, duration: duration)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Supertonic request failed: \(error.localizedDescription)")
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
            // Fallback: estimate based on WAV size (44.1kHz, 16-bit, mono = 88200 bytes/sec)
            let bytesPerSecond: Double = 88_200
            return max(Double(audioData.count - 44) / bytesPerSecond, 0.1)
        }
    }
}
