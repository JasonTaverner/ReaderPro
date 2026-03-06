import Foundation

/// Use Case para crear un nuevo proyecto
/// Coordina la creación del agregado Project y su persistencia
final class CreateProjectUseCase {

    // MARK: - Properties

    private let projectRepository: ProjectRepositoryPort

    // MARK: - Initialization

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Ejecuta el caso de uso de creación de proyecto
    /// - Parameter request: Los datos para crear el proyecto
    /// - Returns: Response con el proyecto creado
    /// - Throws: DomainError si los datos son inválidos, o error de repositorio
    func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse {
        // 1. Validar y crear Value Objects del dominio
        let text: TextContent?
        if let textValue = request.text, !textValue.isEmpty {
            text = try TextContent(textValue)
        } else {
            text = nil  // Proyecto vacío (solo nombre)
        }

        // 2. Crear o generar ProjectName
        let projectName: ProjectName
        if let providedName = request.name {
            // Si se proporciona un nombre explícito, validarlo (lanza error si está vacío)
            projectName = try ProjectName(providedName)
        } else if let text = text {
            // Si no se proporciona nombre (nil), generar automáticamente desde el texto
            projectName = ProjectName.fromText(text)
        } else {
            // Sin nombre y sin texto - usar nombre por defecto
            projectName = try ProjectName("New Project")
        }

        // 3. Crear VoiceConfiguration (usar valores por defecto si no se proporcionan)
        let speed = try VoiceConfiguration.Speed(request.speed ?? 1.0)
        let voiceConfiguration = VoiceConfiguration(
            voiceId: request.voiceId ?? "af_bella",
            speed: speed
        )

        // 4. Crear Voice entity (usar valores por defecto si no se proporcionan)
        let voice = Voice(
            id: request.voiceId ?? "af_bella",
            name: request.voiceName ?? "Bella (Default)",
            language: request.voiceLanguage ?? "en-US",
            provider: request.voiceProvider ?? .kokoro,
            isDefault: true
        )

        // 5. Crear el Aggregate Root (Project)
        let project = Project(
            name: projectName,
            text: text,
            voiceConfiguration: voiceConfiguration,
            voice: voice,
            folderId: request.folderId
        )

        // 6. Persistir el proyecto
        print("[CreateProjectUseCase] Saving new project: \(project.name.value)")
        try await projectRepository.save(project)
        print("[CreateProjectUseCase] Project saved with ID: \(project.id.value)")

        // 7. Retornar Response DTO
        return CreateProjectResponse(
            projectId: project.id,
            projectName: project.name.value,
            folderName: project.folderName,
            status: project.status,
            createdAt: project.createdAt
        )
    }
}
