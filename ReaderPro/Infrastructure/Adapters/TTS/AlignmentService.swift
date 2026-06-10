import Foundation

/// Tiempos por palabra de un audio generado, alineados con su texto original
struct WordTiming: Codable, Equatable {
    let word: String
    let start: Double
    let end: Double
    let charStart: Int
    let charEnd: Int

    enum CodingKeys: String, CodingKey {
        case word, start, end
        case charStart = "char_start"
        case charEnd = "char_end"
    }
}

/// Obtiene los tiempos por palabra de un audio (para el resaltado durante la
/// reproducción) vía el endpoint /align del servidor MLX, con caché en disco
/// junto al audio (<audio>.timings.json). Best-effort: si el servidor no está
/// disponible, simplemente no hay resaltado.
final class AlignmentService {

    private let baseURL: URL
    private let urlSession: URLSession

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8890")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    /// Devuelve los timings del audio: de la caché en disco si existen,
    /// o pidiéndolos al servidor (y guardándolos) si no.
    func loadOrAlign(audioFullPath: String, text: String, language: String) async throws -> [WordTiming] {
        let cacheURL = URL(fileURLWithPath: audioFullPath + ".timings.json")

        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode([WordTiming].self, from: data) {
            return cached
        }

        let timings = try await align(audioFullPath: audioFullPath, text: text, language: language)

        if let data = try? JSONEncoder().encode(timings) {
            try? data.write(to: cacheURL, options: .atomic)
        }
        return timings
    }

    private func align(audioFullPath: String, text: String, language: String) async throws -> [WordTiming] {
        let audioURL = URL(fileURLWithPath: audioFullPath)
        let audioData = try Data(contentsOf: audioURL)

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        appendField("text", text)
        appendField("language", language)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: baseURL.appendingPathComponent("align"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw InfrastructureError.ttsRequestFailed("Alignment failed")
        }

        struct AlignResponse: Codable {
            let words: [WordTiming]
        }
        return try JSONDecoder().decode(AlignResponse.self, from: data).words
    }
}
