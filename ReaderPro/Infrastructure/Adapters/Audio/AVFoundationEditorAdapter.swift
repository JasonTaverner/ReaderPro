import Foundation
import AVFoundation

/// Adaptador que implementa AudioEditorPort usando AVFoundation
/// Proporciona operaciones de edición de audio: trim, merge, concatenate, ajustes
final class AVFoundationEditorAdapter: AudioEditorPort {

    // MARK: - AudioEditorPort Implementation

    func trim(audioPath: String, timeRange: TimeRange) async throws -> String {
        let sourceURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: sourceURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditorError.exportSessionFailed
        }

        let outputURL = generateTempURL(extension: "m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: timeRange.start, preferredTimescale: 44100),
            duration: CMTime(seconds: timeRange.duration, preferredTimescale: 44100)
        )

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioEditorError.trimFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL.path
    }

    func merge(audioPaths: [String]) async throws -> String {
        return try await concatenate(
            audioPaths: audioPaths,
            silenceDuration: 0,
            outputPath: generateTempURL(extension: "wav").path
        )
    }

    func concatenate(
        audioPaths: [String],
        silenceDuration: TimeInterval,
        outputPath: String
    ) async throws -> String {
        guard !audioPaths.isEmpty else {
            throw AudioEditorError.noAudioFiles
        }

        // Crear composición
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioEditorError.trackCreationFailed
        }

        var currentTime = CMTime.zero
        let silenceTime = CMTime(seconds: silenceDuration, preferredTimescale: 44100)

        // Añadir cada archivo de audio
        for (index, audioPath) in audioPaths.enumerated() {
            let audioURL = URL(fileURLWithPath: audioPath)
            let asset = AVURLAsset(url: audioURL)

            // Cargar duración del asset
            let duration = try await asset.load(.duration)

            // Obtener track de audio del asset
            let assetTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let assetTrack = assetTracks.first else {
                throw AudioEditorError.noAudioTrack(audioPath)
            }

            // Insertar audio en la composición
            try audioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: assetTrack,
                at: currentTime
            )

            // Avanzar tiempo actual
            currentTime = CMTimeAdd(currentTime, duration)

            // Añadir silencio entre audios (excepto después del último)
            if index < audioPaths.count - 1 && silenceDuration > 0 {
                currentTime = CMTimeAdd(currentTime, silenceTime)
            }
        }

        // Exportar la composición
        let outputURL = URL(fileURLWithPath: outputPath)

        // Asegurar que el directorio padre existe
        let parentDirectory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDirectory,
            withIntermediateDirectories: true
        )

        // Usar AVAssetWriter para exportar a WAV
        try await exportToWAV(composition: composition, outputURL: outputURL)

        return outputPath
    }

    func adjustSpeed(audioPath: String, rate: Double) async throws -> String {
        guard (0.5...2.0).contains(rate) else {
            throw AudioEditorError.invalidRate
        }

        let sourceURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: sourceURL)

        // Crear composición con velocidad ajustada
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioEditorError.trackCreationFailed
        }

        let duration = try await asset.load(.duration)
        let assetTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let assetTrack = assetTracks.first else {
            throw AudioEditorError.noAudioTrack(audioPath)
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: assetTrack,
            at: .zero
        )

        // Escalar duración
        let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / rate)
        audioTrack.scaleTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            toDuration: scaledDuration
        )

        let outputURL = generateTempURL(extension: "m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditorError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioEditorError.speedAdjustFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL.path
    }

    func adjustVolume(audioPath: String, factor: Double) async throws -> String {
        guard factor > 0 && factor <= 3.0 else {
            throw AudioEditorError.invalidVolume
        }

        let sourceURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: sourceURL)

        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioEditorError.trackCreationFailed
        }

        let duration = try await asset.load(.duration)
        let assetTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let assetTrack = assetTracks.first else {
            throw AudioEditorError.noAudioTrack(audioPath)
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: assetTrack,
            at: .zero
        )

        // Crear audio mix con parámetros de volumen
        let audioMix = AVMutableAudioMix()
        let audioParams = AVMutableAudioMixInputParameters(track: audioTrack)
        audioParams.setVolume(Float(factor), at: .zero)
        audioMix.inputParameters = [audioParams]

        let outputURL = generateTempURL(extension: "m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditorError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioEditorError.volumeAdjustFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL.path
    }

    func fadeIn(audioPath: String, duration: TimeInterval) async throws -> String {
        let sourceURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: sourceURL)

        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioEditorError.trackCreationFailed
        }

        let assetDuration = try await asset.load(.duration)
        let assetTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let assetTrack = assetTracks.first else {
            throw AudioEditorError.noAudioTrack(audioPath)
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: assetDuration),
            of: assetTrack,
            at: .zero
        )

        // Crear audio mix con fade in
        let audioMix = AVMutableAudioMix()
        let audioParams = AVMutableAudioMixInputParameters(track: audioTrack)

        let fadeStart = CMTime.zero
        let fadeEnd = CMTime(seconds: duration, preferredTimescale: 44100)

        audioParams.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: fadeStart, end: fadeEnd))

        audioMix.inputParameters = [audioParams]

        let outputURL = generateTempURL(extension: "m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditorError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioEditorError.fadeFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL.path
    }

    func fadeOut(audioPath: String, duration: TimeInterval) async throws -> String {
        let sourceURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: sourceURL)

        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioEditorError.trackCreationFailed
        }

        let assetDuration = try await asset.load(.duration)
        let assetTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let assetTrack = assetTracks.first else {
            throw AudioEditorError.noAudioTrack(audioPath)
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: assetDuration),
            of: assetTrack,
            at: .zero
        )

        // Crear audio mix con fade out
        let audioMix = AVMutableAudioMix()
        let audioParams = AVMutableAudioMixInputParameters(track: audioTrack)

        let fadeStart = CMTimeSubtract(assetDuration, CMTime(seconds: duration, preferredTimescale: 44100))
        let fadeEnd = assetDuration

        audioParams.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: fadeStart, end: fadeEnd))

        audioMix.inputParameters = [audioParams]

        let outputURL = generateTempURL(extension: "m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditorError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioEditorError.fadeFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL.path
    }

    func getDuration(audioPath: String) async throws -> TimeInterval {
        let audioURL = URL(fileURLWithPath: audioPath)
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    func normalize(audioPath: String) async throws -> String {
        // Normalization is complex with AVFoundation alone
        // For now, return the original path (no-op)
        // A full implementation would require analyzing peak levels and adjusting
        return audioPath
    }

    // MARK: - Private Helpers

    private func generateTempURL(extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + "." + ext
        return tempDir.appendingPathComponent(fileName)
    }

    /// Exporta una composición a formato WAV usando AVAssetWriter
    private func exportToWAV(composition: AVComposition, outputURL: URL) async throws {
        // Eliminar archivo existente si lo hay
        try? FileManager.default.removeItem(at: outputURL)

        // Configurar formato de salida PCM (WAV)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        // Crear asset writer
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .wav)

        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        writerInput.expectsMediaDataInRealTime = false

        assetWriter.add(writerInput)

        // Crear asset reader
        let assetReader = try AVAssetReader(asset: composition)

        let tracks = try await composition.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw AudioEditorError.noAudioTrack("composition")
        }

        let readerOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 24000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        )

        assetReader.add(readerOutput)

        // Iniciar lectura y escritura
        assetWriter.startWriting()
        assetReader.startReading()
        assetWriter.startSession(atSourceTime: .zero)

        // Copiar samples
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.readerpro.audioexport")
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        // Finalizar escritura
        await assetWriter.finishWriting()

        guard assetWriter.status == .completed else {
            throw AudioEditorError.exportFailed(assetWriter.error?.localizedDescription ?? "Unknown")
        }
    }
}

// MARK: - Errors

enum AudioEditorError: LocalizedError {
    case noAudioFiles
    case trackCreationFailed
    case noAudioTrack(String)
    case exportSessionFailed
    case trimFailed(String)
    case speedAdjustFailed(String)
    case volumeAdjustFailed(String)
    case fadeFailed(String)
    case exportFailed(String)
    case invalidRate
    case invalidVolume

    var errorDescription: String? {
        switch self {
        case .noAudioFiles:
            return "No hay archivos de audio para procesar"
        case .trackCreationFailed:
            return "Error al crear track de audio"
        case .noAudioTrack(let path):
            return "No se encontró track de audio en: \(path)"
        case .exportSessionFailed:
            return "Error al crear sesión de exportación"
        case .trimFailed(let reason):
            return "Error al recortar audio: \(reason)"
        case .speedAdjustFailed(let reason):
            return "Error al ajustar velocidad: \(reason)"
        case .volumeAdjustFailed(let reason):
            return "Error al ajustar volumen: \(reason)"
        case .fadeFailed(let reason):
            return "Error al aplicar fade: \(reason)"
        case .exportFailed(let reason):
            return "Error al exportar audio: \(reason)"
        case .invalidRate:
            return "Velocidad inválida (debe estar entre 0.5 y 2.0)"
        case .invalidVolume:
            return "Volumen inválido"
        }
    }
}
