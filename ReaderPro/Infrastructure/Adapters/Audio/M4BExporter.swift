import Foundation
import AVFoundation
import CoreMedia

/// Capítulo de un audiolibro a exportar
struct AudiobookChapter {
    let audioURL: URL
    let title: String
}

/// Exporta un audiolibro .m4b con capítulos navegables (Apple Books, iPhone).
///
/// Pipeline: AVMutableComposition (concatena entradas wav/m4a con formatos
/// mezclados e inserta silencios) → AVAssetReader (PCM uniforme) → AVAssetWriter
/// (contenedor .mp4 renombrado a .m4b) con AAC mono 96 kbps + una pista de texto
/// 'tx3g' referenciada como chapterList — el formato canónico de capítulos que
/// escriben iTunes/ffmpeg y leen Apple Books y el iPhone (verificado con
/// AVAsset.loadChapterMetadataGroups).
enum M4BExporter {

    enum ExporterError: LocalizedError {
        case noChapters
        case compositionFailed
        case readerFailed
        case writerFailed(String)

        var errorDescription: String? {
            switch self {
            case .noChapters: return "No chapters with audio to export"
            case .compositionFailed: return "Could not build the audio composition"
            case .readerFailed: return "Could not read the composed audio"
            case .writerFailed(let reason): return "Audiobook writing failed: \(reason)"
            }
        }
    }

    /// Exporta el audiolibro y devuelve su duración total en segundos.
    static func export(
        chapters: [AudiobookChapter],
        outputURL: URL,
        silenceDuration: TimeInterval,
        bookTitle: String
    ) async throws -> TimeInterval {
        guard !chapters.isEmpty else { throw ExporterError.noChapters }

        // 1. Composición + rangos de capítulo
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw ExporterError.compositionFailed }

        var chapterRanges: [(title: String, range: CMTimeRange)] = []
        var cursor = CMTime.zero
        let silence = CMTime(seconds: silenceDuration, preferredTimescale: 44_100)

        for (index, chapter) in chapters.enumerated() {
            let asset = AVURLAsset(url: chapter.audioURL)
            let duration = try await asset.load(.duration)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }
            let start = cursor
            try track.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: cursor
            )
            cursor = CMTimeAdd(cursor, duration)
            chapterRanges.append((chapter.title, CMTimeRange(start: start, end: cursor)))

            if index < chapters.count - 1 && silenceDuration > 0 {
                composition.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: silence))
                cursor = CMTimeAdd(cursor, silence)
            }
        }
        guard !chapterRanges.isEmpty else { throw ExporterError.noChapters }

        // 2. Reader: PCM uniforme desde la composición (resuelve formatos mixtos)
        let reader = try AVAssetReader(asset: composition)
        let readerOutput = AVAssetReaderAudioMixOutput(
            audioTracks: composition.tracks(withMediaType: .audio),
            audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        guard reader.canAdd(readerOutput) else { throw ExporterError.readerFailed }
        reader.add(readerOutput)

        // 3. Writer (.mp4: el contenedor M4B; .m4a no acepta pistas de capítulos)
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ])
        audioInput.expectsMediaDataInRealTime = false
        writer.add(audioInput)

        // Pista de capítulos: texto tx3g referenciado como chapterList
        guard let textFormat = makeTx3gDescription() else {
            throw ExporterError.writerFailed("tx3g format description")
        }
        let textInput = AVAssetWriterInput(mediaType: .text, outputSettings: nil, sourceFormatHint: textFormat)
        textInput.expectsMediaDataInRealTime = false
        textInput.languageCode = "und"
        // Pista deshabilitada para reproducción: solo sirve de índice de capítulos
        textInput.marksOutputTrackAsEnabled = false
        writer.add(textInput)
        audioInput.addTrackAssociation(withTrackOf: textInput, type: AVAssetTrack.AssociationType.chapterList.rawValue)

        // Metadatos estáticos del libro
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = bookTitle as NSString
        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = "ReaderPro" as NSString
        writer.metadata = [titleItem, artistItem]

        guard writer.startWriting() else {
            throw ExporterError.writerFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        guard reader.startReading() else {
            writer.cancelWriting()
            throw ExporterError.readerFailed
        }
        writer.startSession(atSourceTime: .zero)

        let textSamples = chapterRanges.compactMap {
            makeTextSample($0.title, range: $0.range, description: textFormat)
        }

        // 4. Bombear audio y capítulos EN PARALELO: el muxer no drena la pista de
        // texto hasta que el audio avanza — alimentarlas en secuencia bloquea.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()

            group.enter()
            var pendingSamples = textSamples
            var textDone = false
            textInput.requestMediaDataWhenReady(on: DispatchQueue(label: "m4b.chapters")) {
                guard !textDone else { return }
                while textInput.isReadyForMoreMediaData {
                    if pendingSamples.isEmpty {
                        textDone = true
                        textInput.markAsFinished()
                        group.leave()
                        return
                    }
                    if !textInput.append(pendingSamples.removeFirst()) {
                        textDone = true
                        textInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }

            group.enter()
            var audioDone = false
            audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "m4b.audio")) {
                guard !audioDone else { return }
                while audioInput.isReadyForMoreMediaData {
                    if let sample = readerOutput.copyNextSampleBuffer() {
                        if !audioInput.append(sample) {
                            audioDone = true
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }
                    } else {
                        audioDone = true
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }

            group.notify(queue: DispatchQueue(label: "m4b.done")) {
                continuation.resume()
            }
        }

        await writer.finishWriting()

        if writer.status != .completed {
            throw ExporterError.writerFailed(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
        }

        return CMTimeGetSeconds(cursor)
    }

    // MARK: - tx3g (3GPP timed text)

    /// Descripción de formato 'tx3g' mínima (la misma estructura que escribe ffmpeg)
    private static func makeTx3gDescription() -> CMFormatDescription? {
        var bytes: [UInt8] = []
        func a32(_ v: UInt32) { bytes.append(contentsOf: [UInt8(v >> 24 & 0xff), UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff)]) }
        func a16(_ v: UInt16) { bytes.append(contentsOf: [UInt8(v >> 8 & 0xff), UInt8(v & 0xff)]) }

        a32(0)                                  // size (se rellena al final)
        bytes.append(contentsOf: Array("tx3g".utf8))
        bytes.append(contentsOf: [0, 0, 0, 0, 0, 0]) // reserved
        a16(1)                                  // data reference index
        a32(0)                                  // display flags
        bytes.append(1)                         // horizontal justification
        bytes.append(0xFF)                      // vertical justification (-1)
        a32(0)                                  // background color
        a16(0); a16(0); a16(0); a16(0)          // default text box
        a16(0); a16(0); a16(1)                  // style: startChar, endChar, fontID
        bytes.append(0)                         // face flags
        bytes.append(12)                        // font size
        a32(0xFFFF_FFFF)                        // text color
        let font = "Serif"
        a32(UInt32(8 + 2 + 3 + font.utf8.count)) // ftab box size
        bytes.append(contentsOf: Array("ftab".utf8))
        a16(1); a16(1)                          // count, fontID
        bytes.append(UInt8(font.utf8.count))
        bytes.append(contentsOf: Array(font.utf8))

        let total = UInt32(bytes.count)
        bytes[0] = UInt8(total >> 24 & 0xff); bytes[1] = UInt8(total >> 16 & 0xff)
        bytes[2] = UInt8(total >> 8 & 0xff); bytes[3] = UInt8(total & 0xff)

        var description: CMFormatDescription?
        let status = bytes.withUnsafeBufferPointer { buffer -> OSStatus in
            CMTextFormatDescriptionCreateFromBigEndianTextDescriptionData(
                allocator: kCFAllocatorDefault,
                bigEndianTextDescriptionData: buffer.baseAddress!,
                size: bytes.count,
                flavor: nil,
                mediaType: kCMMediaType_Text,
                formatDescriptionOut: &description
            )
        }
        return status == noErr ? description : nil
    }

    /// Muestra de texto tx3g (longitud big-endian + UTF-8) para un capítulo
    private static func makeTextSample(_ text: String, range: CMTimeRange, description: CMFormatDescription) -> CMSampleBuffer? {
        let utf8 = Array(text.utf8)
        let payload: [UInt8] = [UInt8(utf8.count >> 8 & 0xff), UInt8(utf8.count & 0xff)] + utf8

        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: payload.count, blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0, dataLength: payload.count,
            flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &blockBuffer
        ) == noErr, let block = blockBuffer else { return nil }

        _ = payload.withUnsafeBufferPointer { buffer in
            CMBlockBufferReplaceDataBytes(
                with: buffer.baseAddress!, blockBuffer: block,
                offsetIntoDestination: 0, dataLength: payload.count
            )
        }

        var timing = CMSampleTimingInfo(
            duration: range.duration,
            presentationTimeStamp: range.start,
            decodeTimeStamp: .invalid
        )
        var size = payload.count
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: block, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: description,
            sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }

        return sampleBuffer
    }
}
