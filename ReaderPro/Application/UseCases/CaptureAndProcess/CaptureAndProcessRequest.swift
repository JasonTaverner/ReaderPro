import Foundation

/// Request DTO para capturar pantalla, OCR y guardar como AudioEntry
struct CaptureAndProcessRequest {
    let projectId: Identifier<Project>
    let generateAudio: Bool  // Si true, genera audio automáticamente después del OCR

    init(projectId: Identifier<Project>, generateAudio: Bool = false) {
        self.projectId = projectId
        self.generateAudio = generateAudio
    }
}
