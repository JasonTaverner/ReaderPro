import Foundation
import AVFoundation

/// Adaptador de AudioPlayerPort usando AVAudioPlayer
@MainActor
final class AVAudioPlayerAdapter: NSObject, @preconcurrency AudioPlayerPort, AVAudioPlayerDelegate {

    private var player: AVAudioPlayer?
    private var audioFileURL: URL?

    /// LRU cache for waveform samples keyed by file path
    private var waveformCache: [String: [Float]] = [:]
    private var waveformCacheOrder: [String] = []
    private let maxWaveformCacheSize = 10

    /// Callback que se invoca cuando el audio termina de reproducirse
    var onPlaybackComplete: (() -> Void)?

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    var duration: TimeInterval {
        player?.duration ?? 0
    }

    var rate: Float {
        player?.rate ?? 1.0
    }

    func load(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw NSError(domain: "AVAudioPlayerAdapter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Audio file not found: \(path)"])
        }

        // Read file data off the main thread to avoid blocking UI
        let audioData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url)
        }.value

        // Create player on main thread (required by @MainActor) but data is already loaded
        let newPlayer = try AVAudioPlayer(data: audioData)
        newPlayer.delegate = self
        newPlayer.enableRate = true
        newPlayer.prepareToPlay()
        player = newPlayer
        audioFileURL = url
    }

    func play() async {
        print("[AVAudioPlayerAdapter] play() called, player exists: \(player != nil)")
        player?.play()
    }

    func pause() async {
        print("[AVAudioPlayerAdapter] pause() called")
        player?.pause()
    }

    func stop() async {
        print("[AVAudioPlayerAdapter] stop() called")
        player?.stop()
        player = nil
        audioFileURL = nil
    }

    func seek(to time: TimeInterval) async {
        player?.currentTime = time
    }

    func setRate(_ rate: Float) async {
        player?.rate = rate
    }

    func generateWaveformSamples(sampleCount: Int) async throws -> [Float] {
        guard let url = audioFileURL else { return [] }

        // Check cache first
        let cacheKey = url.path
        if let cached = waveformCache[cacheKey] {
            return cached
        }

        // Run heavy audio processing off the main thread
        let capturedURL = url
        let samples: [Float] = try await Task.detached {
            let file = try AVAudioFile(forReading: capturedURL)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard frameCount > 0 else { return [] }

            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            try file.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return [] }

            let samplesPerBucket = Int(frameCount) / sampleCount
            guard samplesPerBucket > 0 else { return [] }

            var result = [Float]()
            result.reserveCapacity(sampleCount)

            for i in 0..<sampleCount {
                let start = i * samplesPerBucket
                let end = min(start + samplesPerBucket, Int(frameCount))
                var maxAmplitude: Float = 0
                for j in start..<end {
                    let amplitude = abs(channelData[j])
                    if amplitude > maxAmplitude {
                        maxAmplitude = amplitude
                    }
                }
                result.append(maxAmplitude)
            }

            return result
        }.value

        // Store in cache with LRU eviction
        waveformCache[cacheKey] = samples
        waveformCacheOrder.removeAll { $0 == cacheKey }
        waveformCacheOrder.append(cacheKey)
        if waveformCacheOrder.count > maxWaveformCacheSize {
            let evicted = waveformCacheOrder.removeFirst()
            waveformCache.removeValue(forKey: evicted)
        }

        return samples
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("[AVAudioPlayerAdapter] Playback finished, success: \(flag)")
        Task { @MainActor [weak self] in
            self?.onPlaybackComplete?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[AVAudioPlayerAdapter] Decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
