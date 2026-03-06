import Foundation

/// Response DTO después de procesar un documento PDF o EPUB
struct ProcessDocumentResponse {
    let successfulEntries: [ProcessedSection]
    let failedSections: [FailedSection]
    let totalSections: Int
    let documentType: String

    var successCount: Int { successfulEntries.count }
    var failureCount: Int { failedSections.count }

    struct ProcessedSection {
        let entryId: String
        let entryNumber: Int
        let title: String
        let textPreview: String
    }

    struct FailedSection {
        let title: String
        let reason: String
    }
}
