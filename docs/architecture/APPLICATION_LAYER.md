# Application Layer

Orchestrates domain objects via **Use Cases**. Each use case represents one user intention. Depends only on the Domain layer.

## Directory Structure

```
Application/
├── UseCases/
│   ├── GenerateAudio/
│   │   ├── GenerateAudioUseCase.swift
│   │   ├── GenerateAudioRequest.swift
│   │   └── GenerateAudioResponse.swift
│   ├── GenerateAudioForEntry/
│   │   ├── GenerateAudioForEntryUseCase.swift
│   │   ├── GenerateAudioForEntryRequest.swift
│   │   └── GenerateAudioForEntryResponse.swift
│   ├── ManageProjects/
│   │   ├── CreateProjectUseCase.swift
│   │   ├── GetProjectUseCase.swift
│   │   ├── UpdateProjectUseCase.swift
│   │   ├── DeleteProjectUseCase.swift
│   │   ├── ListProjectsUseCase.swift
│   │   └── MergeProjectUseCase.swift
│   ├── SaveAudioEntry/
│   │   ├── SaveAudioEntryUseCase.swift
│   │   ├── SaveAudioEntryRequest.swift
│   │   └── SaveAudioEntryResponse.swift
│   ├── DocumentProcessing/
│   │   ├── CaptureAndProcessUseCase.swift
│   │   ├── ProcessImageBatchUseCase.swift
│   │   ├── ProcessDocumentUseCase.swift
│   │   └── ProcessTextBatchUseCase.swift
│   └── Playback/
│       └── (handled directly by AudioPlayerPort)
└── DTOs/
    ├── ProjectDTO.swift
    ├── ProjectSummary.swift
    ├── VoiceDTO.swift
    └── AudioEntryDTO.swift
```

## Use Cases

### GenerateAudioUseCase

Generates audio for a project's main text.

**Dependencies:** `ProjectRepositoryPort`, `TTSPort`, `AudioStoragePort`

**Flow:**
1. Find project by ID (throw if not found)
2. Validate project has text and can regenerate
3. Mark project as `.generating`, persist
4. Call `ttsPort.synthesize()` with text and voice config
5. Save audio via `audioStorage.save()`
6. Mark project as `.ready` (emits `AudioGeneratedEvent`)
7. Persist and return response

**Error handling:** If TTS or storage fails, marks project as `.error` and persists before rethrowing.

```swift
protocol GenerateAudioUseCaseProtocol {
    func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse
}
```

### GenerateAudioForEntryUseCase

Generates audio for a single `AudioEntry` within a project.

**Dependencies:** `ProjectRepositoryPort`, `TTSPort`, `AudioStoragePort`

**Flow:**
1. Find project and entry
2. Synthesize audio for entry's text
3. Save audio file, update entry's audioPath
4. Persist project

### CreateProjectUseCase

Creates a new project with optional text.

**Dependencies:** `ProjectRepositoryPort`

**Flow:**
1. Create `TextContent` (optional) from request
2. Create `ProjectName` (explicit, auto-from-text, or "New Project")
3. Create `VoiceConfiguration` with defaults (speed 1.0, pitch 1.0)
4. Create `Voice` entity (defaults to `af_bella`, `.kokoro`)
5. Create `Project` aggregate root
6. Persist and return response

### GetProjectUseCase

Loads a project by ID for editing.

**Dependencies:** `ProjectRepositoryPort`, `AudioStoragePort`

**Response includes:**
- Project metadata (id, name, status, dates)
- Voice configuration (voiceId, speed, pitch, provider)
- Entries with absolute audio/image paths
- Thumbnail path

### ListProjectsUseCase

Lists all projects with summary information.

**Dependencies:** `ProjectRepositoryPort`

**Features:**
- Sortable by `updatedAt` or `createdAt`
- Ascending or descending order
- Returns `[ProjectSummary]` with name, entry count, text preview, thumbnail

### UpdateProjectUseCase

Updates project metadata (name, text, voice config).

**Dependencies:** `ProjectRepositoryPort`

**Flow:**
1. Find project
2. Apply changes (rename, updateText, updateVoiceConfiguration)
3. Persist

### DeleteProjectUseCase

Deletes a project and all its files.

**Dependencies:** `ProjectRepositoryPort`

### MergeProjectUseCase

Creates a merged export of all project entries.

**Dependencies:** `ProjectRepositoryPort`, `AudioStoragePort`, `AudioEditorPort`, `PDFGeneratorPort`

**Creates a `Fusion_XXX/` folder containing:**
- `documento_completo.txt` — all texts concatenated
- `audio_completo.wav` — all audio files merged
- `imagenes.pdf` — all images in a single PDF

### SaveAudioEntryUseCase

Saves a new text/audio/image entry to a project.

**Dependencies:** `ProjectRepositoryPort`, `AudioStoragePort`

**Flow:**
1. Find project
2. Create `AudioEntry` with text
3. Save audio file if provided
4. Save image file if provided
5. Add entry to project aggregate
6. Persist

### CaptureAndProcessUseCase

Captures a screenshot and extracts text via OCR.

**Dependencies:** `ScreenCapturePort`, `OCRPort`

### ProcessImageBatchUseCase

Processes multiple images, extracting text from each via OCR.

**Dependencies:** `OCRPort`, `ProjectRepositoryPort`, `AudioStoragePort`

### ProcessDocumentUseCase

Processes PDF/EPUB documents, extracting text from all pages.

**Dependencies:** `DocumentParserPort`, `OCRPort`, `ProjectRepositoryPort`

### ProcessTextBatchUseCase

Splits a long text into multiple entries, optionally generating audio for each.

**Dependencies:** `ProjectRepositoryPort`, `AudioStoragePort`, `TTSPort`

## Request/Response DTOs

Each use case defines its own request and response types for clean boundaries.

**Example — GenerateAudioRequest:**
```swift
struct GenerateAudioRequest {
    let projectId: Identifier<Project>
}
```

**Example — GenerateAudioResponse:**
```swift
struct GenerateAudioResponse {
    let projectId: Identifier<Project>
    let audioPath: String
    let duration: TimeInterval
    let status: ProjectStatus
}
```

**Example — CreateProjectRequest:**
```swift
struct CreateProjectRequest {
    let name: String
    let text: String?
    let voiceId: String?
    let speed: Double?
    let pitch: Double?
}
```

## Protocol Pattern

Each use case defines a protocol for testability:

```swift
protocol CreateProjectUseCaseProtocol {
    func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse
}

final class CreateProjectUseCase: CreateProjectUseCaseProtocol {
    // ...
}
```

This allows presenters to depend on protocols and tests to inject mocks.

## Wiring

All use cases are `lazy var` properties in `DependencyContainer`:

```swift
lazy var createProjectUseCase: CreateProjectUseCaseProtocol = CreateProjectUseCase(
    projectRepository: projectRepository
)

lazy var generateAudioUseCase: GenerateAudioUseCaseProtocol = GenerateAudioUseCase(
    projectRepository: projectRepository,
    ttsPort: ttsAdapterProxy,
    audioStorage: audioStorage
)
```
