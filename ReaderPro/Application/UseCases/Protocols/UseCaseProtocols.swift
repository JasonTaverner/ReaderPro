import Foundation

// MARK: - Use Case Protocols
// These protocols allow dependency injection of mock use cases in tests

protocol ListProjectsUseCaseProtocol {
    func execute(_ request: ListProjectsRequest) async throws -> ListProjectsResponse
}

protocol DeleteProjectUseCaseProtocol {
    func execute(_ request: DeleteProjectRequest) async throws -> DeleteProjectResponse
}

protocol CreateProjectUseCaseProtocol {
    func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse
}

protocol GetProjectUseCaseProtocol {
    func execute(_ request: GetProjectRequest) async throws -> GetProjectResponse
}

protocol UpdateProjectUseCaseProtocol {
    func execute(_ request: UpdateProjectRequest) async throws -> UpdateProjectResponse
}

protocol GenerateAudioUseCaseProtocol {
    func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse
}

protocol SaveAudioEntryUseCaseProtocol {
    func execute(_ request: SaveAudioEntryRequest) async throws -> SaveAudioEntryResponse
}

protocol CaptureAndProcessUseCaseProtocol {
    func execute(_ request: CaptureAndProcessRequest) async throws -> CaptureAndProcessResponse
}

protocol ProcessImageBatchUseCaseProtocol {
    func execute(_ request: ProcessImageBatchRequest) async throws -> ProcessImageBatchResponse
}

protocol ProcessDocumentUseCaseProtocol {
    func execute(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse
}

protocol GenerateAudioForEntryUseCaseProtocol {
    func execute(_ request: GenerateAudioForEntryRequest) async throws -> GenerateAudioForEntryResponse
}

// MARK: - Folder Use Case Protocols

protocol CreateFolderUseCaseProtocol {
    func execute(name: String, colorHex: String) async throws -> Identifier<Folder>
}

protocol ListFoldersUseCaseProtocol {
    func execute() async throws -> [FolderSummary]
}

protocol RenameFolderUseCaseProtocol {
    func execute(folderId: Identifier<Folder>, newName: String) async throws
}

protocol DeleteFolderUseCaseProtocol {
    func execute(folderId: Identifier<Folder>) async throws
}

protocol AssignProjectToFolderUseCaseProtocol {
    func execute(projectId: Identifier<Project>, folderId: Identifier<Folder>?) async throws
}

// MARK: - Conformances

extension ListProjectsUseCase: ListProjectsUseCaseProtocol {}
extension DeleteProjectUseCase: DeleteProjectUseCaseProtocol {}
extension CreateProjectUseCase: CreateProjectUseCaseProtocol {}
extension GetProjectUseCase: GetProjectUseCaseProtocol {}
extension UpdateProjectUseCase: UpdateProjectUseCaseProtocol {}
extension GenerateAudioUseCase: GenerateAudioUseCaseProtocol {}
extension SaveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol {}
extension ProcessImageBatchUseCase: ProcessImageBatchUseCaseProtocol {}
extension ProcessDocumentUseCase: ProcessDocumentUseCaseProtocol {}
extension GenerateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol {}
