import Foundation

/// Identificador único type-safe para AudioEntry
/// Wrapper sobre Identifier<AudioEntry> para mayor claridad
/// (AudioEntry Entity se define en Domain/ProjectManagement/Entities/)
typealias EntryId = Identifier<AudioEntry>
