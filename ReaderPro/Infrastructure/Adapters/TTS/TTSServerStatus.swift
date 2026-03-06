import Foundation

/// Estado compartido para servidores TTS (Kokoro, Qwen3, etc.)
enum TTSServerStatus: Equatable {
    case unknown
    case starting
    case connected
    case disconnected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isRetryable: Bool {
        switch self {
        case .disconnected, .error:
            return true
        default:
            return false
        }
    }
}
