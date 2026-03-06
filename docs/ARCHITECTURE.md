# Architecture

ReaderPro follows **Domain-Driven Design (DDD)** with **Hexagonal Architecture (Ports & Adapters)** and is developed using **Test-Driven Development (TDD)**.

## Table of Contents

- [Why This Architecture?](#why-this-architecture)
- [Layer Diagram](#layer-diagram)
- [Layer Responsibilities](#layer-responsibilities)
- [Dependency Rule](#dependency-rule)
- [Request Flow Example](#request-flow-example)
- [Bounded Contexts](#bounded-contexts)
- [Key Design Decisions](#key-design-decisions)

## Why This Architecture?

1. **Testability**: Domain logic has zero external dependencies - it can be tested with pure unit tests, no mocks needed for frameworks.
2. **Flexibility**: TTS providers can be swapped at runtime (Kokoro ONNX, Kokoro Server, Qwen3) without changing domain or application code.
3. **Separation of Concerns**: Each layer has a single responsibility. UI knows nothing about persistence. Domain knows nothing about SwiftUI.
4. **App Store Ready**: Clean architecture makes it easier to sandbox the app and pass Apple review.

## Layer Diagram

```
┌──────────────────────────────────────────────────────────┐
│                     INFRASTRUCTURE                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │                   APPLICATION                       │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │                  DOMAIN                       │  │  │
│  │  │                                               │  │  │
│  │  │  Entities, Value Objects, Domain Services,    │  │  │
│  │  │  Aggregates, Domain Events, Ports             │  │  │
│  │  │                                               │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  Use Cases, Application Services, DTOs              │  │
│  │                                                     │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  Adapters: SwiftUI, FileSystem, ONNX Runtime,            │
│  AVFoundation, Vision, MLX Server, PDFKit                │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### Domain (innermost)
- **No external dependencies** (no Foundation imports where possible)
- Contains business rules and logic
- Defines Ports (interfaces) that adapters must implement
- Value Objects are immutable (`struct` with `let`)
- Entities have identity (unique `id`)
- Aggregates protect invariants

### Application
- Orchestrates domain objects via Use Cases
- Each Use Case = one user intention
- Depends only on Domain layer
- Defines DTOs for external communication

### Infrastructure (outermost)
- Implements Ports defined in Domain
- Contains all "dirty" code: frameworks, APIs, file I/O
- Adapters are interchangeable (e.g., swap TTS provider)

### UI
- SwiftUI Views (input adapter)
- Presenters coordinate with Use Cases
- ViewModels hold UI-only state
- Views are "dumb" - no business logic

## Dependency Rule

Dependencies always point **inward**:

```
UI → Application → Domain ← Infrastructure
```

- Domain depends on nothing
- Application depends on Domain
- Infrastructure implements Domain ports
- UI calls Application use cases

**Never**: Domain importing SwiftUI, Application importing AVFoundation, etc.

## Request Flow Example

**User generates audio for a project:**

```
1. [UI] User taps "Generate Audio" in ProjectDetailView
     │
2. [Presenter] EditorPresenter.generateAudio()
     │  - Builds VoiceConfiguration from ViewModel state
     │  - Calls TTSPort.synthesize()
     │
3. [Proxy] TTSAdapterProxy delegates to active adapter
     │
4. [Infrastructure] Qwen3TTSAdapter.synthesize()
     │  - Builds JSON request body
     │  - POST to localhost:8890/synthesize
     │  - Receives WAV binary
     │
5. [Application] SaveAudioEntryUseCase.execute()
     │  - Creates AudioEntry domain entity
     │  - Writes WAV to FileSystem via AudioStoragePort
     │  - Updates Project aggregate
     │  - Persists via ProjectRepositoryPort
     │
6. [UI] Presenter reloads entries, UI updates reactively
```

## Bounded Contexts

| Context | Responsibility |
|---|---|
| **Audio Generation** | TTS synthesis, voice configuration |
| **Project Management** | Projects, entries, persistence |
| **Audio Editing** | Trim, merge, speed adjust |
| **Document Processing** | OCR, PDF/EPUB parsing, screenshots |
| **Playback** | Audio player, waveform, controls |
| **Translation** | Text translation between languages |
| **Clipboard & Hotkeys** | Paste capture, global shortcuts |

## Key Design Decisions

### TTSAdapterProxy for Runtime Switching
Rather than rebuilding the dependency graph when the user switches TTS provider, a proxy pattern is used. `TTSAdapterProxy` wraps the current adapter and all use cases reference the proxy. When the coordinator switches provider, only the proxy's `current` property changes.

### Lazy Model Loading
Both Kokoro ONNX and Qwen3 models load on first use, not at app startup. The Qwen3 server's `ModelManager` keeps only one model in memory at a time, unloading the previous one when switching between CustomVoice, VoiceDesign, and Base (cloning).

### File-Based Persistence
Projects are stored as folders on disk (`~/Documents/KokoroLibrary/<project>/`) with sequential numbered files (`001.txt`, `001.wav`, `001.png`). This makes projects portable, easy to browse in Finder, and avoids database complexity.

### DependencyContainer Singleton
All wiring happens in `DependencyContainer.shared`. Use Cases are `lazy var` properties, ensuring single instances. Presenters are created via factory methods (`makeEditorPresenter()`) to get fresh instances per screen.

---

See detailed documentation for each layer:
- [Domain Layer](architecture/DOMAIN_LAYER.md)
- [Application Layer](architecture/APPLICATION_LAYER.md)
- [Infrastructure Layer](architecture/INFRASTRUCTURE_LAYER.md)
- [UI Layer](architecture/UI_LAYER.md)
