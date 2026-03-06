# Adding Features

Step-by-step guide for adding new functionality to ReaderPro, following the architecture and TDD practices.

## Overview

Adding a feature typically touches 4 layers. Work from the inside out:

```
1. Domain (Value Objects, Entities, Ports)
2. Application (Use Cases, DTOs)
3. Infrastructure (Adapters)
4. UI (ViewModel, Presenter, View)
```

## Example: Adding a New TTS Provider

### Step 1: Domain — Define the Port Contract

The `TTSPort` protocol already exists. If your provider needs new capabilities, extend it or create a new port.

If the provider introduces a new `TTSProvider` case:

```swift
// Domain/AudioGeneration/Entities/Voice.swift
enum TTSProvider: String, CaseIterable {
    case native
    case kokoro
    case qwen3
    case newProvider  // Add new case
}
```

**Write tests first** (TDD):
```swift
func test_newProvider_shouldHaveDisplayName() {
    XCTAssertEqual(Voice.TTSProvider.newProvider.displayName, "New Provider")
}
```

### Step 2: Application — Update Use Cases if Needed

If the new provider requires different request parameters, update the relevant DTOs.

Usually no changes needed here — use cases depend on `TTSPort` which is provider-agnostic.

### Step 3: Infrastructure — Create the Adapter

Create a new adapter implementing `TTSPort`:

```swift
// Infrastructure/Adapters/TTS/NewProviderTTSAdapter.swift
final class NewProviderTTSAdapter: TTSPort {
    var isAvailable: Bool { get async { ... } }
    var provider: Voice.TTSProvider { .newProvider }

    func availableVoices() async -> [Voice] { ... }
    func synthesize(text: TextContent, voiceConfiguration: VoiceConfiguration, voice: Voice) async throws -> AudioData { ... }
}
```

**Add to Xcode project:** New `.swift` files must be added to `project.pbxproj` with entries in:
- `PBXBuildFile`
- `PBXFileReference`
- `PBXGroup` (under the appropriate group)
- `PBXSourcesBuildPhase`

Use a unique 24-character hex ID for each pbxproj entry.

### Step 4: Infrastructure — Wire in DependencyContainer

```swift
// App/DependencyContainer.swift
lazy var newProviderAdapter: NewProviderTTSAdapter = NewProviderTTSAdapter()
```

Update `TTSServerCoordinator` to handle the new provider in `switchProvider()`.

### Step 5: UI — Add Provider Option

Update `TTSServerCoordinator` to include the new provider in its available providers list. The UI (provider dropdown) reads from the coordinator.

### Step 6: Tests

Write tests at each layer:
- **Domain:** Voice.TTSProvider enum tests
- **Infrastructure:** Adapter unit tests (mock HTTP responses)
- **Application:** Use case tests with mock adapter
- **UI:** Presenter tests verifying provider switching

## Example: Adding a New Value Object

### Step 1: Write Failing Tests

```swift
// Tests/Domain/NewContext/ValueObjects/NewValueTests.swift
func test_init_withValidData_shouldSucceed() throws {
    let value = try NewValue("valid")
    XCTAssertEqual(value.data, "valid")
}

func test_init_withInvalidData_shouldThrow() {
    XCTAssertThrowsError(try NewValue(""))
}
```

### Step 2: Implement the Value Object

```swift
// Domain/NewContext/ValueObjects/NewValue.swift
struct NewValue: Equatable {
    let data: String

    init(_ data: String) throws {
        guard !data.isEmpty else {
            throw DomainError.invalidData("Cannot be empty")
        }
        self.data = data
    }
}
```

### Step 3: Add to pbxproj

Add the file reference and build phase entries.

## Example: Adding a New Use Case

### Step 1: Define Protocol

```swift
protocol NewUseCaseProtocol {
    func execute(_ request: NewRequest) async throws -> NewResponse
}
```

### Step 2: Define Request/Response

```swift
struct NewRequest { let projectId: Identifier<Project> }
struct NewResponse { let result: String }
```

### Step 3: Implement

```swift
final class NewUseCase: NewUseCaseProtocol {
    private let projectRepository: ProjectRepositoryPort

    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }

    func execute(_ request: NewRequest) async throws -> NewResponse {
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }
        // Business logic here
        return NewResponse(result: "done")
    }
}
```

### Step 4: Wire in DependencyContainer

```swift
lazy var newUseCase: NewUseCaseProtocol = NewUseCase(
    projectRepository: projectRepository
)
```

### Step 5: Add to Presenter

```swift
// In EditorPresenter init, add dependency
// Add method that calls the use case
func performNewAction() async {
    do {
        let response = try await newUseCase.execute(NewRequest(projectId: ...))
        viewModel.someProperty = response.result
    } catch {
        viewModel.error = error.localizedDescription
    }
}
```

### Step 6: Add UI

Add button/control in the appropriate view that calls `presenter.performNewAction()`.

## Checklist

- [ ] Domain types have no framework imports
- [ ] Value Objects are `struct` with `let` properties
- [ ] Tests written before implementation (TDD)
- [ ] Use Case has a protocol for testability
- [ ] New files added to `project.pbxproj`
- [ ] Mock created for new ports
- [ ] All existing tests still pass
