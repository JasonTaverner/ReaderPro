import Foundation

/// Tipo de merge a realizar
enum MergeType: String, CaseIterable {
    case audio      // Solo audios → audio_completo.wav
    case images     // Solo imágenes → documento.pdf
    case text       // Solo textos → documento_completo.txt
    case all        // Todo (audio + imágenes + texto)
}

/// Request para el caso de uso de merge de proyecto
struct MergeProjectRequest {
    /// ID del proyecto cuyos entries se van a mergear
    let projectId: Identifier<Project>

    /// Tipo de merge a realizar
    let mergeType: MergeType

    /// Duración del silencio entre audios (solo aplica para audio merge)
    /// Default: 0.5 segundos
    let silenceBetweenAudios: TimeInterval

    init(
        projectId: Identifier<Project>,
        mergeType: MergeType,
        silenceBetweenAudios: TimeInterval = 0.5
    ) {
        self.projectId = projectId
        self.mergeType = mergeType
        self.silenceBetweenAudios = silenceBetweenAudios
    }
}
