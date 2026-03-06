import Foundation

/// Proxy que delega a un TTSPort activo, permitiendo cambiar de proveedor en runtime
/// Thread-safe: usa NSLock para proteger el acceso al adapter actual
final class TTSAdapterProxy: TTSPort, @unchecked Sendable {

    // MARK: - Properties

    private let lock = NSLock()
    private var _current: TTSPort

    /// El adapter actualmente activo
    var current: TTSPort {
        get { lock.withLock { _current } }
        set { lock.withLock { _current = newValue } }
    }

    // MARK: - Initialization

    init(_ initial: TTSPort) {
        self._current = initial
    }

    // MARK: - TTSPort Conformance

    var provider: Voice.TTSProvider {
        current.provider
    }

    var isAvailable: Bool {
        get async {
            await current.isAvailable
        }
    }

    func availableVoices() async -> [Voice] {
        await current.availableVoices()
    }

    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData {
        try await current.synthesize(
            text: text,
            voiceConfiguration: voiceConfiguration,
            voice: voice
        )
    }
}
