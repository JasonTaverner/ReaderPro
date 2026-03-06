import Foundation

/// Request DTO para procesar un documento PDF o EPUB
struct ProcessDocumentRequest {
    let projectId: Identifier<Project>
    let documentURL: URL
    let onProgress: ((Int, Int) -> Void)?

    init(
        projectId: Identifier<Project>,
        documentURL: URL,
        onProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.projectId = projectId
        self.documentURL = documentURL
        self.onProgress = onProgress
    }
}
