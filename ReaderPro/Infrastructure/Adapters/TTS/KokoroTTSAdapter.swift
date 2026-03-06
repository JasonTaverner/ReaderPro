import Foundation
import AVFoundation

/// Adapter para Kokoro TTS que se comunica con un servidor HTTP local
/// El servidor debe estar corriendo en http://localhost:8880
///
/// Endpoints:
/// - GET  /health     → Health check
/// - POST /synthesize → { "text": "...", "voice": "...", "speed": 1.0 }
final class KokoroTTSAdapter: TTSPort {

    // MARK: - Properties

    private let baseURL: URL
    private let urlSession: URLSessionProtocol
    private let healthCheckTimeout: TimeInterval = 2.0
    private let synthesizeTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    /// Inicializa el adapter con una URL base y URLSession
    /// - Parameters:
    ///   - baseURL: URL del servidor Kokoro (default: http://localhost:8880)
    ///   - urlSession: URLSession para hacer requests (inyectable para testing)
    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8880")!,
        urlSession: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - TTSPort Implementation

    var provider: Voice.TTSProvider {
        .kokoro
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
        // Voces de Kokoro TTS v1.0
        // Referencia: https://github.com/thewh1teagle/kokoro-onnx
        return [
            // === ESPAÑOL (Default) ===
            Voice(
                id: "em_santa",
                name: "Santa",
                language: "es-ES",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "ef_dora",
                name: "Dora (Español)",
                language: "es-ES",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "em_alex",
                name: "Alex (Español)",
                language: "es-ES",
                provider: .kokoro,
                isDefault: true
            ),

            // === INGLÉS AMERICANO ===
            Voice(
                id: "af_bella",
                name: "Bella (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "af_nicole",
                name: "Nicole (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "af_sarah",
                name: "Sarah (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "af_sky",
                name: "Sky (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "am_adam",
                name: "Adam (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "am_michael",
                name: "Michael (American)",
                language: "en-US",
                provider: .kokoro,
                isDefault: false
            ),

            // === INGLÉS BRITÁNICO ===
            Voice(
                id: "bf_emma",
                name: "Emma (British)",
                language: "en-GB",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "bf_isabella",
                name: "Isabella (British)",
                language: "en-GB",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "bm_george",
                name: "George (British)",
                language: "en-GB",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "bm_lewis",
                name: "Lewis (British)",
                language: "en-GB",
                provider: .kokoro,
                isDefault: false
            ),

            // === FRANCÉS ===
            Voice(
                id: "ff_siwis",
                name: "Siwis (Français)",
                language: "fr-FR",
                provider: .kokoro,
                isDefault: false
            ),

            // === ITALIANO ===
            Voice(
                id: "if_sara",
                name: "Sara (Italiano)",
                language: "it-IT",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "im_nicola",
                name: "Nicola (Italiano)",
                language: "it-IT",
                provider: .kokoro,
                isDefault: false
            ),

            // === PORTUGUÉS (Brasil) ===
            Voice(
                id: "pf_dora",
                name: "Dora (Português)",
                language: "pt-BR",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "pm_alex",
                name: "Alex (Português)",
                language: "pt-BR",
                provider: .kokoro,
                isDefault: false
            ),

            // === JAPONÉS ===
            Voice(
                id: "jf_alpha",
                name: "Alpha (日本語)",
                language: "ja-JP",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "jm_kumo",
                name: "Kumo (日本語)",
                language: "ja-JP",
                provider: .kokoro,
                isDefault: false
            ),

            // === CHINO ===
            Voice(
                id: "zf_xiaobei",
                name: "Xiaobei (中文)",
                language: "zh-CN",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "zm_yunxi",
                name: "Yunxi (中文)",
                language: "zh-CN",
                provider: .kokoro,
                isDefault: false
            ),

            // === COREANO ===
            Voice(
                id: "kf_sarah",
                name: "Sarah (한국어)",
                language: "ko-KR",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "km_kevin",
                name: "Kevin (한국어)",
                language: "ko-KR",
                provider: .kokoro,
                isDefault: false
            ),

            // === HINDI ===
            Voice(
                id: "hf_alpha",
                name: "Alpha (हिन्दी)",
                language: "hi-IN",
                provider: .kokoro,
                isDefault: false
            ),
            Voice(
                id: "hm_omega",
                name: "Omega (हिन्दी)",
                language: "hi-IN",
                provider: .kokoro,
                isDefault: false
            ),
        ]
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        // 1. Construir URL
        let synthesizeURL = baseURL.appendingPathComponent("synthesize")

        // 2. Construir request JSON (incluir language para phonemización correcta)
        print("[KokoroTTSAdapter] Sending voice: \(voiceConfiguration.voiceId), language: \(voice.language)")
        let requestBody: [String: Any] = [
            "text": text.value,
            "voice": voiceConfiguration.voiceId,
            "speed": voiceConfiguration.speed.value,
            "lang": voice.language
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw InfrastructureError.ttsRequestFailed("Failed to encode JSON")
        }

        // 3. Configurar request
        var request = URLRequest(url: synthesizeURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = synthesizeTimeout

        // 4. Hacer request con manejo de errores de conexión
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw InfrastructureError.ttsRequestFailed(error.localizedDescription)
        }

        // 5. Validar respuesta
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.ttsRequestFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw InfrastructureError.ttsRequestFailed(
                "Server returned status code \(httpResponse.statusCode)"
            )
        }

        // 6. Validar que es audio WAV
        guard data.count > 44 else {
            throw InfrastructureError.ttsRequestFailed("Invalid audio data (too small)")
        }

        // 7. Obtener duración del audio
        let duration = try await getDuration(of: data)

        // 8. Crear AudioData
        return try AudioData(data: data, duration: duration)
    }

    /// Mapea errores de URL a errores de infraestructura más descriptivos
    private func mapURLError(_ error: URLError) -> InfrastructureError {
        let serverURL = baseURL.absoluteString

        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            // Connection refused - server not running
            return .ttsServerNotRunning(url: serverURL)

        case .timedOut:
            // Request timed out
            return .ttsServerTimeout(url: serverURL)

        case .notConnectedToInternet:
            return .ttsRequestFailed("No hay conexión a internet")

        case .secureConnectionFailed:
            return .ttsRequestFailed("Error de conexión segura")

        default:
            return .ttsRequestFailed("Error de red: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Obtiene la duración de un audio WAV usando AVFoundation
    private func getDuration(of audioData: Data) async throws -> TimeInterval {
        // Crear archivo temporal
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Escribir datos al archivo temporal
        try audioData.write(to: tempURL)

        // Usar AVAudioFile para obtener duración
        do {
            let audioFile = try AVAudioFile(forReading: tempURL)
            let frameCount = audioFile.length
            let sampleRate = audioFile.processingFormat.sampleRate
            let duration = Double(frameCount) / sampleRate
            return duration
        } catch {
            // Fallback: estimar basado en tamaño
            // WAV: ~176KB/sec (44.1kHz, 16-bit, stereo)
            let bytesPerSecond: Double = 176_400
            return max(Double(audioData.count) / bytesPerSecond, 1.0)
        }
    }
}
