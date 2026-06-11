import Foundation
import AVFoundation

/// Storage de audio basado en sistema de archivos que implementa AudioStoragePort
/// Audio files are stored inside each project's directory:
/// ~/Documents/ReaderProLibrary/
/// ├── ProjectName/
/// │   ├── project.json
/// │   ├── 001.txt, 001.png
/// │   └── 001.wav, 002.wav   ← audio files numbered sequentially
final class FileSystemAudioStorage: AudioStoragePort {

    // MARK: - Properties

    private let baseDirectoryURL: URL
    private let fileManager: FileManager

    /// Serializa asignación de número secuencial + escritura: dos saves
    /// concurrentes con entryNumber nil escaneaban el directorio a la vez,
    /// obtenían el mismo número y un fichero sobreescribía al otro
    private let saveLock = NSLock()

    var baseDirectory: String {
        baseDirectoryURL.path
    }

    // MARK: - Initialization

    /// Inicializa el storage con un directorio base
    /// - Parameter baseDirectory: Directorio base donde se almacenarán los audios
    ///                            Por defecto: ~/Documents/ReaderProLibrary/
    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        if let baseDirectory = baseDirectory {
            self.baseDirectoryURL = baseDirectory
        } else {
            // Default: ~/Documents/ReaderProLibrary/
            let documentsDirectory = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            self.baseDirectoryURL = documentsDirectory.appendingPathComponent(
                "ReaderProLibrary",
                isDirectory: true
            )
        }

        self.fileManager = fileManager

        createBaseDirectoryIfNeeded()
    }

    // MARK: - AudioStoragePort Implementation

    func save(audioData: AudioData, folderName: String, entryNumber: Int?) async throws -> String {
        // 1. Determine the project directory
        let dirURL = baseDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: dirURL.path) {
            try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        // 2. Determine filename: use provided number or auto-detect next
        saveLock.lock()
        defer { saveLock.unlock() }

        let number: Int
        if let entryNumber = entryNumber {
            number = entryNumber
        } else {
            number = nextSequentialNumber(in: dirURL, ext: "wav")
        }

        // 3. Comprimir a AAC/M4A (~6-10x menos disco que WAV; transparente para voz).
        // Toda la app lee .m4a igual que .wav (AVAudioPlayer/AVAudioFile); los WAV
        // antiguos siguen funcionando tal cual. Si la codificación falla, se guarda
        // el WAV original (comportamiento previo).
        if let m4aFilename = try? Self.encodeToM4A(wavData: audioData.data, in: dirURL, number: number) {
            let relativePath = "\(folderName)/\(m4aFilename)"
            print("[FileSystemAudioStorage] Saved compressed audio: \(relativePath)")
            return relativePath
        }

        let filename = String(format: "%03d.wav", number)
        let relativePath = "\(folderName)/\(filename)"

        // 3b. Get full path (fallback WAV)
        let fileURL = dirURL.appendingPathComponent(filename)

        print("[FileSystemAudioStorage] Saving audio: \(relativePath)")
        print("[FileSystemAudioStorage] Full path: \(fileURL.path)")
        print("[FileSystemAudioStorage] Data size: \(audioData.data.count) bytes")

        // 4. Write data to file
        do {
            try audioData.data.write(to: fileURL, options: .atomic)
        } catch {
            print("[FileSystemAudioStorage] ERROR writing file: \(error)")
            throw InfrastructureError.fileWriteFailed(fileURL.path)
        }

        let exists = fileManager.fileExists(atPath: fileURL.path)
        print("[FileSystemAudioStorage] File written successfully. Exists: \(exists)")

        // 5. Return relative path (folderName/001.wav)
        return relativePath
    }

    func load(path: String) async throws -> AudioData {
        // 1. Get full URL
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        // 2. Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw InfrastructureError.fileNotFound(path)
        }

        // 3. Load data
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw InfrastructureError.fileReadFailed(path)
        }

        // 4. Get duration using AVFoundation
        let duration = try await getDuration(of: fileURL)

        // 5. Create AudioData
        return try AudioData(data: data, duration: duration)
    }

    func delete(path: String) async throws {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        // Only attempt to delete if file exists (idempotent)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw InfrastructureError.fileWriteFailed("Failed to delete: \(path)")
        }
    }

    func export(path: String, format: AudioFormat, quality: AudioQuality) async throws -> Data {
        // For now, just return the file data
        // In a real implementation, this would convert the format
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw InfrastructureError.fileNotFound(path)
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw InfrastructureError.fileReadFailed(path)
        }
    }

    func copy(from sourcePath: String, to destinationPath: String) async throws {
        let sourceURL = baseDirectoryURL.appendingPathComponent(sourcePath)
        let destURL = baseDirectoryURL.appendingPathComponent(destinationPath)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw InfrastructureError.fileNotFound(sourcePath)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw InfrastructureError.fileWriteFailed("Failed to copy to: \(destinationPath)")
        }
    }

    func move(from sourcePath: String, to destinationPath: String) async throws {
        let sourceURL = baseDirectoryURL.appendingPathComponent(sourcePath)
        let destURL = baseDirectoryURL.appendingPathComponent(destinationPath)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw InfrastructureError.fileNotFound(sourcePath)
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destURL)
        } catch {
            throw InfrastructureError.fileWriteFailed("Failed to move to: \(destinationPath)")
        }
    }

    func exists(path: String) async -> Bool {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func getSize(path: String) async throws -> Int {
        let fileURL = baseDirectoryURL.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw InfrastructureError.fileNotFound(path)
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? Int else {
                throw InfrastructureError.fileReadFailed("Could not get size of: \(path)")
            }
            return size
        } catch {
            throw InfrastructureError.fileReadFailed(path)
        }
    }

    func generateUniquePath(folderName: String, format: AudioFormat) async -> String {
        let dirURL = baseDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
        let ext = format.fileExtension
        let number = nextSequentialNumber(in: dirURL, ext: ext)
        let filename = String(format: "%03d.%@", number, ext)
        return "\(folderName)/\(filename)"
    }

    // MARK: - Private Helpers

    /// Finds the next sequential number for files in a directory with a given extension
    /// Scans existing files like 001.wav, 002.wav and returns max + 1
    /// Codifica un WAV en memoria a AAC (.m4a) en el directorio dado.
    /// Devuelve el nombre de fichero (NNN.m4a) o lanza si la codificación falla.
    private static func encodeToM4A(wavData: Data, in dirURL: URL, number: Int) throws -> String {
        let tempWAV = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        try wavData.write(to: tempWAV)
        defer { try? FileManager.default.removeItem(at: tempWAV) }

        let inFile = try AVAudioFile(forReading: tempWAV)
        let format = inFile.processingFormat

        let filename = String(format: "%03d.m4a", number)
        let outURL = dirURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outURL)

        // 64 kbps para 24 kHz (Kokoro/Qwen3/Chatterbox), 96 kbps para 44-48 kHz
        // (Supertonic/VoxCPM2): transparente para voz
        let bitRate = format.sampleRate >= 44_100 ? 96_000 : 64_000
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: bitRate,
        ]

        do {
            let outFile = try AVAudioFile(forWriting: outURL, settings: settings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else {
                throw InfrastructureError.fileWriteFailed(outURL.path)
            }
            while inFile.framePosition < inFile.length {
                try inFile.read(into: buffer)
                if buffer.frameLength == 0 { break }
                try outFile.write(from: buffer)
            }
        } catch {
            // No dejar un .m4a a medias
            try? FileManager.default.removeItem(at: outURL)
            throw error
        }

        return filename
    }

    private func nextSequentialNumber(in directory: URL, ext: String) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 1
        }

        var maxNumber = 0
        // El audio puede ser .wav (antiguo) o .m4a (comprimido): contar ambos
        let audioExtensions = ext == "wav" ? ["wav", "m4a"] : [ext]
        for url in contents where audioExtensions.contains(url.pathExtension) {
            let name = url.deletingPathExtension().lastPathComponent
            if let number = Int(name) {
                maxNumber = max(maxNumber, number)
            }
        }
        return maxNumber + 1
    }

    /// Creates the base directory if it doesn't exist
    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try? fileManager.createDirectory(
                at: baseDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// Gets the duration of an audio file using AVFoundation
    private func getDuration(of fileURL: URL) async throws -> TimeInterval {
        // Use AVAudioFile to get accurate duration
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let frameCount = audioFile.length
            let sampleRate = audioFile.processingFormat.sampleRate
            let duration = Double(frameCount) / sampleRate
            return duration
        } catch {
            // Fallback: estimate based on file size (for WAV: ~176KB/sec)
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int else {
                return 1.0
            }

            // Estimate assuming WAV format (44.1kHz, 16-bit, stereo)
            let bytesPerSecond: Double = 176_400
            return max(Double(fileSize) / bytesPerSecond, 1.0)
        }
    }
}
