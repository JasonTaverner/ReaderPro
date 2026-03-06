import Foundation
import AVFoundation

/// Adapter para Qwen3-TTS que se comunica con el servidor MLX local
/// El servidor debe estar corriendo en http://localhost:8890
///
/// Endpoints:
/// - GET  /health     → Health check
/// - GET  /voices     → Lista de voces premium
/// - POST /synthesize → TTS con speaker + instruct (JSON)
/// - POST /clone      → Voice cloning con audio de referencia (multipart/form-data)
final class Qwen3TTSAdapter: TTSPort {

    // MARK: - Properties

    private let baseURL: URL
    private let urlSession: URLSessionProtocol
    private let healthCheckTimeout: TimeInterval = 2.0
    private let synthesizeTimeout: TimeInterval = 600.0

    // MARK: - Initialization

    /// Inicializa el adapter con la URL del servidor MLX
    /// - Parameters:
    ///   - baseURL: URL del servidor Qwen3 MLX (default: http://localhost:8890)
    ///   - urlSession: URLSession para hacer requests (inyectable para testing)
    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8890")!,
        urlSession: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - TTSPort Implementation

    var provider: Voice.TTSProvider {
        .qwen3
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
        // 9 premium voices from the MLX model
        return [
            Voice(id: "Vivian", name: "Vivian", language: "multi", provider: .qwen3, isDefault: true),
            Voice(id: "Serena", name: "Serena", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Uncle_Fu", name: "Uncle Fu", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Dylan", name: "Dylan", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Eric", name: "Eric", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Ryan", name: "Ryan", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Aiden", name: "Aiden", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Ono_Anna", name: "Ono Anna", language: "multi", provider: .qwen3, isDefault: false),
            Voice(id: "Sohee", name: "Sohee", language: "multi", provider: .qwen3, isDefault: false),
        ]
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        // Check if voice cloning is requested
        if let referenceURL = voiceConfiguration.referenceAudioURL {
            return try await synthesizeWithCloning(
                text: text,
                voiceConfiguration: voiceConfiguration,
                referenceAudioURL: referenceURL
            )
        }

        // Standard synthesis with speaker + optional instruct
        return try await synthesizeStandard(
            text: text,
            voiceConfiguration: voiceConfiguration,
            voice: voice
        )
    }

    // MARK: - Standard Synthesis

    private func synthesizeStandard(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        let synthesizeURL = baseURL.appendingPathComponent("synthesize")

        // Determine mode: voice_design if voiceDesignInstruct is set
        let isVoiceDesign = voiceConfiguration.voiceDesignInstruct != nil

        // Build JSON body
        var requestBody: [String: Any] = [
            "text": text.value,
            "speed": voiceConfiguration.speed.value,
            "mode": isVoiceDesign ? "voice_design" : "custom_voice",
        ]

        if isVoiceDesign {
            // VoiceDesign mode: instruct is the complete voice description, no speaker needed
            // Use accent language if available, otherwise "auto"
            requestBody["language"] = voiceConfiguration.voiceDesignLanguage ?? "auto"
            requestBody["instruct"] = voiceConfiguration.voiceDesignInstruct!
            print("[Qwen3TTSAdapter] Synthesizing (VoiceDesign): lang=\(voiceConfiguration.voiceDesignLanguage ?? "auto"), instruct=\(voiceConfiguration.voiceDesignInstruct!.prefix(100))")
        } else {
            // CustomVoice mode: speaker required, instruct optional (emotion/style)
            requestBody["language"] = "auto"
            requestBody["speaker"] = voice.id
            if let instruct = voiceConfiguration.instruct {
                requestBody["instruct"] = instruct
            }
            print("[Qwen3TTSAdapter] Synthesizing (CustomVoice): speaker=\(voice.id), instruct=\(voiceConfiguration.instruct ?? "nil")")
        }

        // Log the full request body for diagnostics
        if let debugJSON = try? JSONSerialization.data(withJSONObject: requestBody, options: .sortedKeys),
           let debugStr = String(data: debugJSON, encoding: .utf8) {
            print("[Qwen3TTSAdapter] Request body: \(debugStr)")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw InfrastructureError.ttsRequestFailed("Failed to encode JSON for Qwen3")
        }

        var request = URLRequest(url: synthesizeURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from Qwen3 MLX server")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = extractErrorMessage(from: data) ?? "Status \(httpResponse.statusCode)"
            throw InfrastructureError.ttsRequestFailed("Qwen3 MLX error: \(errorMsg)")
        }

        // Response is raw WAV binary
        let duration = try getDuration(of: data)
        return try AudioData(data: data, duration: duration)
    }

    // MARK: - Voice Cloning

    private func synthesizeWithCloning(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        referenceAudioURL: URL
    ) async throws -> AudioData {
        let cloneURL = baseURL.appendingPathComponent("clone")

        // Read reference audio
        let audioData: Data
        do {
            audioData = try Data(contentsOf: referenceAudioURL)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Failed to read reference audio: \(error.localizedDescription)")
        }

        // Build multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Audio file field
        let filename = referenceAudioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Text field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append(text.value.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Language field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Speed field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"speed\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(voiceConfiguration.speed.value)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Reference Text field (highly recommended to avoid Whisper errors)
        if let refText = voiceConfiguration.referenceText, !refText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ref_text\"\r\n\r\n".data(using: .utf8)!)
            body.append(refText.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            print("[Qwen3TTSAdapter] Providing ref_text (\(refText.count) chars)")
        }

        // Clone optimization: x_vector_only (faster, less accurate)
        if voiceConfiguration.cloneFastMode {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"x_vector_only\"\r\n\r\n".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            print("[Qwen3TTSAdapter] Clone fast mode enabled (x_vector_only)")
        }

        // Clone optimization: lightweight 0.6B model
        if voiceConfiguration.cloneFastModel {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"fast_model\"\r\n\r\n".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            print("[Qwen3TTSAdapter] Clone fast model enabled (0.6B)")
        }

        // Accent instruct: steers pronunciation without changing voice timbre
        if let accentInstruct = voiceConfiguration.cloneAccentInstruct, !accentInstruct.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"accent_instruct\"\r\n\r\n".data(using: .utf8)!)
            body.append(accentInstruct.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            print("[Qwen3TTSAdapter] Clone accent instruct: \(accentInstruct.prefix(80))")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("[Qwen3TTSAdapter] Cloning voice from: \(filename)")

        var request = URLRequest(url: cloneURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        let (responseData, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from Qwen3 MLX server")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = extractErrorMessage(from: responseData) ?? "Status \(httpResponse.statusCode)"
            throw InfrastructureError.ttsRequestFailed("Qwen3 MLX clone error: \(errorMsg)")
        }

        let duration = try getDuration(of: responseData)
        return try AudioData(data: responseData, duration: duration)
    }

    // MARK: - Transcription

    /// Transcribes audio to text using the server's /transcribe endpoint (mlx-whisper).
    /// - Parameter url: Local file URL of the audio to transcribe
    /// - Returns: Transcribed text
    func transcribeAudio(url: URL) async throws -> String {
        let transcribeURL = baseURL.appendingPathComponent("transcribe")

        // Read audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: url)
        } catch {
            throw InfrastructureError.ttsRequestFailed("Failed to read audio file: \(error.localizedDescription)")
        }

        // Build multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        let filename = url.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: transcribeURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        let (responseData, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response from transcription server")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = extractErrorMessage(from: responseData) ?? "Status \(httpResponse.statusCode)"
            throw InfrastructureError.ttsRequestFailed("Transcription error: \(errorMsg)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let text = json["text"] as? String else {
            throw InfrastructureError.ttsRequestFailed("Invalid transcription response format")
        }

        return text
    }

    // MARK: - Generation Progress

    /// Progress state returned by the server's /progress endpoint
    struct GenerationProgress {
        let active: Bool
        let mode: String
        let segmentsDone: Int
        let segmentsTotal: Int
        let currentMessage: String
        let detailMessage: String
        let elapsed: TimeInterval
    }

    /// Polls the server for current generation progress.
    /// Returns nil on any error (non-blocking, best-effort).
    func fetchProgress() async -> GenerationProgress? {
        let progressURL = baseURL.appendingPathComponent("progress")
        var request = URLRequest(url: progressURL)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            return GenerationProgress(
                active: json["active"] as? Bool ?? false,
                mode: json["mode"] as? String ?? "",
                segmentsDone: json["segments_done"] as? Int ?? 0,
                segmentsTotal: json["segments_total"] as? Int ?? 0,
                currentMessage: json["current_message"] as? String ?? "",
                detailMessage: json["detail_message"] as? String ?? "",
                elapsed: json["elapsed"] as? TimeInterval ?? 0
            )
        } catch {
            return nil
        }
    }

    /// Sends a cancel request to the server to abort in-progress generation.
    /// Best-effort: returns true if the server acknowledged, false otherwise.
    func cancelGeneration() async -> Bool {
        let cancelURL = baseURL.appendingPathComponent("cancel")
        var request = URLRequest(url: cancelURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["cancelled"] as? Bool ?? false
            }
            return false
        } catch {
            print("[Qwen3TTSAdapter] Cancel request failed: \(error)")
            return false
        }
    }

    // MARK: - Model Management

    /// Response from /models endpoint
    struct ModelStatus {
        let loadedModel: String?
        let loadedModelId: String?
    }

    /// Fetches the current model status from the server
    func fetchModelStatus() async throws -> ModelStatus {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.timeoutInterval = healthCheckTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw InfrastructureError.ttsRequestFailed("Failed to fetch model status")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InfrastructureError.ttsRequestFailed("Invalid model status response")
        }

        return ModelStatus(
            loadedModel: json["loaded_model"] as? String,
            loadedModelId: json["loaded_model_id"] as? String
        )
    }

    /// Unloads the current model on the server to free memory
    func unloadModel() async throws -> String? {
        let unloadURL = baseURL.appendingPathComponent("unload")
        var request = URLRequest(url: unloadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = healthCheckTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw InfrastructureError.ttsRequestFailed("Failed to unload model")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json["unloaded"] as? String
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw InfrastructureError.ttsRequestFailed(error.localizedDescription)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        struct ServerError: Codable {
            let error: String?
        }
        return try? JSONDecoder().decode(ServerError.self, from: data).error
    }

    private func mapURLError(_ error: URLError) -> InfrastructureError {
        let serverURL = baseURL.absoluteString

        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            return .ttsServerNotRunning(url: serverURL)
        case .timedOut:
            return .ttsServerTimeout(url: serverURL)
        default:
            return .ttsRequestFailed("Qwen3 MLX network error: \(error.localizedDescription)")
        }
    }

    /// Obtiene la duración de un audio WAV usando AVFoundation
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
