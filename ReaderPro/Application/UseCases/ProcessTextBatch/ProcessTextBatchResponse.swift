import Foundation

/// Response from ProcessTextBatchUseCase
struct ProcessTextBatchResponse {
    /// Project ID
    let projectId: Identifier<Project>

    /// Number of entries successfully created
    let entriesCreated: Int

    /// Number of entries that have audio
    let entriesWithAudio: Int

    /// Number of entries created without audio (requested but failed, or not requested)
    let entriesWithoutAudio: Int

    /// Text fragments that were created (preview of each)
    let fragments: [String]

    /// Number of failures (if any)
    let failureCount: Int

    /// Error messages for failures
    let errors: [String]

    /// Total number of fragments detected
    var totalFragments: Int {
        entriesCreated + failureCount
    }

    /// Whether all fragments were successfully processed
    var isComplete: Bool {
        failureCount == 0
    }
}
