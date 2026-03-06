import Foundation

/// Status of a generation job
enum GenerationJobStatus: String {
    case queued
    case preparing
    case processing
    case finalizing
    case completed
    case cancelled
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: return true
        default: return false
        }
    }
}

/// Log severity level
enum GenerationLogLevel {
    case info
    case success
    case warning
    case error
}

/// A single log entry emitted during generation
struct GenerationLogEntry: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let level: GenerationLogLevel
    let message: String
}

/// Type of generation job
enum GenerationJobType {
    case projectText
    case entry
    case entryBatch
    case textBatch
    case imageBatch
}

/// Observable model representing a single audio generation job
@MainActor
final class GenerationJob: ObservableObject, Identifiable {

    let id = UUID()
    let type: GenerationJobType
    let projectName: String
    let startedAt = Date()

    @Published var status: GenerationJobStatus = .queued
    @Published var progress: Double? = nil
    @Published var statusMessage: String = "Starting generation..."
    @Published var elapsedSeconds: TimeInterval = 0
    @Published private(set) var logs: [GenerationLogEntry] = []
    @Published var errorMessage: String?
    /// Live token-level detail (e.g. "42% 504/1200 [00:32<01:12, 9.66tokens/s]")
    @Published var detailMessage: String = ""

    /// Formatted elapsed time (m:ss)
    var elapsedFormatted: String {
        let m = Int(elapsedSeconds) / 60
        let s = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Estimated time remaining (nil if indeterminate)
    var estimatedRemainingSeconds: TimeInterval? {
        guard let progress = progress, progress > 0.05 else { return nil }
        let totalEstimate = elapsedSeconds / progress
        let remaining = totalEstimate - elapsedSeconds
        return remaining > 0 ? remaining : nil
    }

    /// Formatted ETA (m:ss or nil)
    var etaFormatted: String? {
        guard let remaining = estimatedRemainingSeconds else { return nil }
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "~%d:%02d", m, s)
    }

    init(type: GenerationJobType, projectName: String) {
        self.type = type
        self.projectName = projectName
    }

    func appendLog(_ message: String, level: GenerationLogLevel = .info) {
        let entry = GenerationLogEntry(
            timestamp: elapsedSeconds,
            level: level,
            message: message
        )
        logs.append(entry)
    }

    /// Updates the live detail message (token-level progress from tqdm).
    /// Only updates if the content actually changed to avoid unnecessary redraws.
    func updateDetail(_ detail: String) {
        if detail != detailMessage {
            detailMessage = detail
        }
    }
}
