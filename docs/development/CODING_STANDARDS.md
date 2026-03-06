# Coding Standards

## Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Domain Entities | PascalCase | `Project`, `Voice`, `AudioEntry` |
| Value Objects | PascalCase | `TextContent`, `ProjectName`, `TimeRange` |
| Ports (Interfaces) | Suffix `Port` | `TTSPort`, `ProjectRepositoryPort` |
| Adapters | Suffix `Adapter` | `KokoroONNXAdapter`, `VisionOCRAdapter` |
| Use Cases | Suffix `UseCase` | `CreateProjectUseCase`, `GenerateAudioUseCase` |
| Use Case Protocols | Suffix `UseCaseProtocol` | `CreateProjectUseCaseProtocol` |
| Tests | Suffix `Tests` | `ProjectTests`, `GenerateAudioUseCaseTests` |
| ViewModels | Suffix `ViewModel` | `EditorViewModel`, `ProjectListViewModel` |
| Presenters | Suffix `Presenter` | `EditorPresenter`, `ProjectListPresenter` |
| Views | Suffix `View` | `ProjectDetailView`, `WaveformView` |
| DTOs | Suffix `DTO` | `VoiceDTO`, `AudioEntryDTO` |
| Errors | Suffix `Error` | `DomainError`, `InfrastructureError` |

## Test Naming

```swift
func test_[method]_[condition]_[expectedResult]()
```

Examples:
```swift
func test_createProject_withEmptyName_shouldThrow()
func test_updateText_whenProjectHasAudio_shouldInvalidateAudio()
func test_execute_withValidRequest_shouldReturnResponse()
func test_tokenize_unknownCharacters_shouldBeDropped()
```

## Layer Rules

### Domain Layer
- **NO** imports of external frameworks (except Foundation when unavoidable)
- Value Objects are **immutable** (`struct` with `let`)
- Entities have **identity** (unique `id`)
- Aggregates protect **invariants**
- Business logic lives in **domain**, not in use cases

### Application Layer
- Use cases orchestrate, **never** contain business logic
- Each use case = **one user intention**
- Depends **only** on Domain layer
- Request/Response DTOs for external communication

### Infrastructure Layer
- Implements ports from Domain
- Contains all framework code (AVFoundation, Vision, ONNX Runtime, etc.)
- Adapters are **interchangeable**

### UI Layer
- Views are **stateless** — no business logic
- Presenters coordinate with use cases
- ViewModels hold **UI-only state**
- Use `@MainActor` for all UI-thread work

## Code Structure

### Arrange-Act-Assert

All tests follow AAA:

```swift
func test_example() throws {
    // Arrange
    let input = try TextContent("test")

    // Act
    let result = input.wordCount

    // Assert
    XCTAssertEqual(result, 1)
}
```

### MARK Comments

Use MARK comments to organize code sections:

```swift
// MARK: - Published Properties
// MARK: - Dependencies
// MARK: - Initialization
// MARK: - View Lifecycle
// MARK: - User Actions
// MARK: - Private Methods
```

### Async/Await

- Use `async/await` for all asynchronous operations
- Use `@MainActor` for presenter and ViewModel classes
- Use `Task.detached` for CPU-intensive work (waveform generation, inference)
- Never block the main thread

### Error Handling

- Domain errors use `DomainError` enum
- Application errors use `ApplicationError` enum
- Infrastructure errors use specific error types per adapter
- Presenters catch errors and set `viewModel.error` for UI display

## SwiftUI Patterns

### Binding Proxies

Views create `Binding(get:set:)` to connect ViewModel properties with Presenter methods:

```swift
private var nameBinding: Binding<String> {
    Binding(
        get: { presenter.viewModel.name },
        set: { presenter.updateName($0) }
    )
}
```

### Nested ObservableObject

Propagate changes from nested ViewModels:

```swift
viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
    self?.objectWillChange.send()
}
```

### Conditional UI

Use computed properties for conditional view logic:

```swift
private var isQwen3Selected: Bool {
    // Check provider from available voices
}
```

## File Organization

- One type per file (exceptions for closely related types)
- File name matches primary type name
- Group files by bounded context, then by DDD building block
- Tests mirror the source directory structure

## pbxproj

When adding new Swift files:
- IDs are 24-character hex strings
- Must add entries in: `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`
- Use consistent ID prefix per feature (e.g., `CC00xx` for KokoroONNX, `DD00xx` for VoiceDesign)

## Language

- Code: English (variable names, comments)
- Error messages: Spanish (user-facing `localizedDescription`)
- Documentation: English
