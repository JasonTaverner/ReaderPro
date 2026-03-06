import Foundation

// MARK: - UI Extensions

extension ProjectSummary: Identifiable {
    var id: String {
        projectId.value.uuidString
    }
}

extension ProjectSummary: Equatable {
    static func == (lhs: ProjectSummary, rhs: ProjectSummary) -> Bool {
        lhs.projectId == rhs.projectId
    }
}

extension ProjectSummary {
    /// Duración formateada como string ("3:45" o nil)
    var durationFormatted: String? {
        // TODO: Calcular desde el audio real cuando esté disponible
        guard hasAudio else { return nil }
        return "1:23" // Placeholder
    }

    /// Estado como string legible
    var statusString: String {
        status.rawValue
    }

    /// Formatea la fecha de actualización de forma relativa
    var formattedUpdatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    /// Proveedor de voz como string
    var providerString: String {
        switch voiceProvider {
        case .native:
            return "Native"
        case .kokoro:
            return "Kokoro"
        case .qwen3:
            return "Qwen3"
        }
    }
}
