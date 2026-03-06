import Foundation
import Combine

/// Singleton that owns audio generation tasks, progress polling, and cancellation.
/// Extracted from EditorPresenter so generation can continue while the user navigates.
@MainActor
final class GenerationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = GenerationManager()

    // MARK: - Published State

    @Published var activeJob: GenerationJob?
    @Published var isPanelExpanded: Bool = false
    @Published var isPanelVisible: Bool = false

    // MARK: - Computed

    /// Whether a generation job is currently running (non-terminal)
    var isActive: Bool {
        guard let job = activeJob else { return false }
        return !job.status.isTerminal
    }

    // MARK: - Dependencies

    private var ttsCoordinator: TTSServerCoordinator?

    // MARK: - Private State

    private var generationTask: Task<Void, Never>?
    private var elapsedTimerTask: Task<Void, Never>?
    private var progressPollingTask: Task<Void, Never>?
    private var jobCancellable: AnyCancellable?

    // MARK: - Initialization

    private init() {}

    /// Configure with TTS coordinator. Call once from DependencyContainer.
    func configure(ttsCoordinator: TTSServerCoordinator) {
        self.ttsCoordinator = ttsCoordinator
    }

    // MARK: - Public API

    /// Starts a new generation job.
    /// - Parameters:
    ///   - type: The kind of generation (projectText, entry, etc.)
    ///   - projectName: Display name for the panel
    ///   - work: Async closure that performs the actual generation. Receives the job to update status.
    /// - Returns: The created GenerationJob
    @discardableResult
    func startJob(
        type: GenerationJobType,
        projectName: String,
        work: @escaping (GenerationJob) async -> Void
    ) -> GenerationJob {
        // Cancel any existing job
        cancelCurrentJob()

        let job = GenerationJob(type: type, projectName: projectName)
        activeJob = job
        isPanelVisible = true
        isPanelExpanded = false

        // Subscribe to job's objectWillChange to propagate changes
        jobCancellable = job.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Start elapsed timer
        elapsedTimerTask = Task { [weak job] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                job?.elapsedSeconds += 1
            }
        }

        // Start progress poller
        progressPollingTask = Task { [weak self, weak job] in
            // Wait before first poll
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            while !Task.isCancelled {
                guard let self = self, let job = job else { break }
                if let progress = await self.ttsCoordinator?.fetchGenerationProgress() {
                    if progress.active {
                        if progress.segmentsTotal > 1 {
                            job.progress = Double(progress.segmentsDone) / Double(progress.segmentsTotal)
                        } else {
                            job.progress = nil
                        }

                        let newMessage = progress.currentMessage
                        if !newMessage.isEmpty && newMessage != job.statusMessage {
                            job.statusMessage = newMessage
                            job.appendLog(newMessage)
                        }

                        // Token-level progress from tqdm (e.g. "42% 504/1200 [00:32<01:12, 9.66tokens/s]")
                        let detail = progress.detailMessage
                        if !detail.isEmpty {
                            job.updateDetail(detail)
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        // Start actual work
        generationTask = Task { [weak self, weak job] in
            guard let job = job else { return }

            await work(job)

            // When work finishes, stop tracking
            self?.stopTracking()

            // If the job is still not terminal (work completed normally without setting status),
            // mark it as completed
            if !job.status.isTerminal {
                job.status = .completed
                job.appendLog("Generation finished (\(job.elapsedFormatted))", level: .success)
            }
        }

        return job
    }

    /// Cancels the currently running generation job.
    func cancelCurrentJob() {
        guard let job = activeJob, !job.status.isTerminal else { return }

        print("[GenerationManager] Cancelling generation...")
        job.appendLog("Cancelling generation...", level: .warning)

        // Cancel the Swift Task
        generationTask?.cancel()
        generationTask = nil

        // Notify the server
        Task {
            let _ = await ttsCoordinator?.cancelGeneration()
        }

        // Stop tracking
        stopTracking()

        // Mark cancelled
        job.status = .cancelled
        job.statusMessage = "Cancelled"
    }

    /// Hides the panel after a terminal state.
    func dismissPanel() {
        isPanelVisible = false
        // Clear the job after dismissal
        activeJob = nil
        jobCancellable = nil
    }

    // MARK: - Private

    private func stopTracking() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = nil
        progressPollingTask?.cancel()
        progressPollingTask = nil
    }
}
