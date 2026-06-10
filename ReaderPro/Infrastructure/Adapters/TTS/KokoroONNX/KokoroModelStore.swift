import Foundation
import Combine

/// Localiza y descarga los modelos de Kokoro (kokoro-v1.0.onnx + voices-v1.0.bin).
///
/// Orden de búsqueda: bundle de la app → Application Support → rutas de desarrollo.
/// Si no están instalados, `downloadIfNeeded()` los descarga automáticamente desde
/// las releases de kokoro-onnx a Application Support, de modo que la app distribuida
/// no necesita incluir los ~350 MB de modelos en el bundle.
final class KokoroModelStore: ObservableObject {

    // MARK: - State

    enum State: Equatable {
        case checking
        case installed
        case downloading(progress: Double) // 0.0–1.0 sobre el total de ambos ficheros
        case failed(message: String)
    }

    static let shared = KokoroModelStore()

    /// Actualizado siempre desde el hilo principal
    @Published private(set) var state: State = .checking

    private var downloadTask: Task<Void, Never>?

    // MARK: - Download sources

    // Releases oficiales de thewh1teagle/kokoro-onnx: mismos ficheros que usa la app en desarrollo
    private static let remoteModelURL = URL(string: "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx")!
    private static let remoteVoicesURL = URL(string: "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin")!

    // Tamaños aproximados para ponderar el progreso global y validar las descargas
    private static let expectedModelBytes: Int64 = 326_000_000
    private static let expectedVoicesBytes: Int64 = 27_000_000

    // MARK: - Install locations

    /// Directorio de instalación: ~/Library/Application Support/ReaderPro/Models/kokoro
    static var installDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReaderPro/Models/kokoro", isDirectory: true)
    }

    static var installedModelURL: URL {
        installDirectory.appendingPathComponent("kokoro-v1.0.onnx")
    }

    static var installedVoicesURL: URL {
        installDirectory.appendingPathComponent("voices-v1.0.bin")
    }

    // MARK: - Discovery

    /// Busca el modelo ONNX: bundle → Application Support → rutas de desarrollo
    static func locateModel() -> String? {
        if let bundled = Bundle.main.path(forResource: "kokoro-v1.0", ofType: "onnx")
            ?? Bundle.main.path(forResource: "kokoro", ofType: "onnx") {
            return bundled
        }

        if FileManager.default.fileExists(atPath: installedModelURL.path) {
            return installedModelURL.path
        }

        return firstExistingPath(relative: [
            "scripts/Resources/Models/kokoro/kokoro-v1.0.onnx",
            "kokoro.onnx",
        ])
    }

    /// Busca el fichero de voces: bundle → Application Support → rutas de desarrollo
    static func locateVoices() -> URL? {
        if let bundled = Bundle.main.url(forResource: "voices-v1.0", withExtension: "bin")
            ?? Bundle.main.url(forResource: "voices", withExtension: "bin") {
            return bundled
        }

        if FileManager.default.fileExists(atPath: installedVoicesURL.path) {
            return installedVoicesURL
        }

        return firstExistingPath(relative: [
            "scripts/Resources/Models/kokoro/voices-v1.0.bin",
            "voices.bin",
        ]).map { URL(fileURLWithPath: $0) }
    }

    static var areModelsInstalled: Bool {
        locateModel() != nil && locateVoices() != nil
    }

    private static func firstExistingPath(relative paths: [String]) -> String? {
        var candidates = paths
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            candidates += paths.map { "\(sourceRoot)/\($0)" }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Download

    /// Descarga los modelos si no están disponibles. Idempotente: se puede llamar en cada arranque.
    @MainActor
    func downloadIfNeeded() {
        guard downloadTask == nil else { return }

        if Self.areModelsInstalled {
            state = .installed
            return
        }

        state = .downloading(progress: 0)
        downloadTask = Task.detached(priority: .utility) { [weak self] in
            await self?.performDownload()
            await MainActor.run { [weak self] in
                self?.downloadTask = nil
            }
        }
    }

    /// Reintento manual tras un fallo (expuesto a la UI)
    @MainActor
    func retry() {
        guard case .failed = state else { return }
        downloadTask?.cancel()
        downloadTask = nil
        downloadIfNeeded()
    }

    private func setState(_ newState: State) {
        Task { @MainActor [weak self] in
            self?.state = newState
        }
    }

    private func performDownload() async {
        do {
            try FileManager.default.createDirectory(at: Self.installDirectory, withIntermediateDirectories: true)

            let totalExpected = Self.expectedModelBytes + Self.expectedVoicesBytes

            if !FileManager.default.fileExists(atPath: Self.installedModelURL.path) {
                try await download(
                    from: Self.remoteModelURL,
                    to: Self.installedModelURL,
                    minimumBytes: 100_000_000
                ) { [weak self] bytes in
                    self?.setState(.downloading(progress: Double(bytes) / Double(totalExpected)))
                }
            }

            if !FileManager.default.fileExists(atPath: Self.installedVoicesURL.path) {
                try await download(
                    from: Self.remoteVoicesURL,
                    to: Self.installedVoicesURL,
                    minimumBytes: 10_000_000
                ) { [weak self] bytes in
                    let done = Self.expectedModelBytes + bytes
                    self?.setState(.downloading(progress: Double(done) / Double(totalExpected)))
                }
            }

            setState(.installed)
            print("[KokoroModelStore] Models installed at \(Self.installDirectory.path)")
        } catch is CancellationError {
            setState(.failed(message: "Download cancelled"))
        } catch {
            print("[KokoroModelStore] Download failed: \(error.localizedDescription)")
            setState(.failed(message: error.localizedDescription))
        }
    }

    /// Descarga un fichero con progreso, escribiendo a un temporal y moviéndolo al destino al validar
    private func download(
        from url: URL,
        to destination: URL,
        minimumBytes: Int64,
        onProgress: @escaping (Int64) -> Void
    ) async throws {
        let temporaryURL = destination.appendingPathExtension("part")
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporaryURL)
        defer { try? handle.close() }

        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        var buffer = [UInt8]()
        buffer.reserveCapacity(1 << 16)
        var written: Int64 = 0
        var lastReported: Int64 = 0

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count == 1 << 16 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                try Task.checkCancellation()
                // Notificar cada ~4 MB para no saturar el hilo principal
                if written - lastReported >= 1 << 22 {
                    lastReported = written
                    onProgress(written)
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
        }
        try handle.close()

        guard written >= minimumBytes else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw URLError(.zeroByteResource)
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        onProgress(written)
    }
}
