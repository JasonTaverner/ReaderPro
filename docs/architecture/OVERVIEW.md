# Architecture Overview

ReaderPro uses **Domain-Driven Design (DDD)** with **Hexagonal Architecture (Ports & Adapters)**, developed following **Test-Driven Development (TDD)**.

## Why This Stack?

| Goal | Solution |
|---|---|
| **Testability** | Domain has zero framework dependencies — pure unit tests, no mocks needed |
| **Flexibility** | TTS providers swap at runtime via proxy pattern |
| **Separation** | Each layer has one job; UI knows nothing about persistence |
| **App Store** | Clean boundaries simplify sandboxing and Apple review |

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

## Dependency Rule

Dependencies always point **inward**:

```
UI → Application → Domain ← Infrastructure
```

- **Domain** depends on nothing
- **Application** depends on Domain
- **Infrastructure** implements Domain ports
- **UI** calls Application use cases

**Never**: Domain importing SwiftUI, Application importing AVFoundation, etc.

## Bounded Contexts

| Context | Responsibility | Key Types |
|---|---|---|
| **Audio Generation** | TTS synthesis, voice config | `TTSPort`, `Voice`, `VoiceConfiguration`, `AudioData` |
| **Project Management** | Projects, entries, persistence | `Project`, `AudioEntry`, `ProjectRepositoryPort` |
| **Audio Editing** | Trim, merge, speed adjust | `AudioSegment`, `TimeRange`, `AudioEditorPort` |
| **Document Processing** | OCR, PDF/EPUB, screenshots | `OCRPort`, `DocumentParserPort`, `ScreenCapturePort` |
| **Playback** | Audio player, waveform | `AudioPlayerPort`, `WaveformView` |
| **Translation** | Text translation | `TranslationPort` |
| **Clipboard & Hotkeys** | Paste capture, global shortcuts | `ClipboardPort`, `HotkeyPort` |

## Request Flow

**User generates audio for an entry:**

```
1. [UI] User taps "Generate Audio" in ProjectDetailView
     │
2. [Presenter] EditorPresenter.generateAudioForEntry()
     │  - Builds VoiceConfiguration from ViewModel state
     │  - Calls GenerateAudioForEntryUseCase.execute()
     │
3. [UseCase] Validates project, delegates to TTSPort
     │
4. [Proxy] TTSAdapterProxy delegates to active adapter
     │
5. [Infrastructure] Qwen3TTSAdapter.synthesize()
     │  - Builds JSON request body
     │  - POST to localhost:8890/synthesize
     │  - Receives WAV binary
     │
6. [UseCase] Saves audio via AudioStoragePort
     │  - Updates AudioEntry with audio path
     │  - Persists Project via ProjectRepositoryPort
     │
7. [UI] Presenter reloads entries, UI updates reactively
```

## Key Design Decisions

### TTSAdapterProxy for Runtime Switching

Rather than rebuilding the dependency graph when the user switches TTS provider, a **proxy pattern** is used. `TTSAdapterProxy` wraps the current adapter and all use cases reference the proxy. When `TTSServerCoordinator` switches provider, only the proxy's `current` property changes.

### Lazy Model Loading

Both Kokoro ONNX and Qwen3 models load on first use, not at app startup. The Qwen3 server's `ModelManager` keeps only one model in memory at a time, unloading the previous one when switching between CustomVoice, VoiceDesign, and Base (cloning).

### File-Based Persistence

Projects are stored as folders on disk with JSON metadata and sequential numbered files. This makes projects portable, browsable in Finder, and avoids database complexity.

### DependencyContainer Singleton

All wiring happens in `DependencyContainer.shared`. Use Cases are `lazy var` properties ensuring single instances. Presenters are created via factory methods to get fresh instances per screen.

## See Also

- [Domain Layer](DOMAIN_LAYER.md) — Entities, Value Objects, Aggregates, Ports
- [Application Layer](APPLICATION_LAYER.md) — Use Cases, DTOs
- [Infrastructure Layer](INFRASTRUCTURE_LAYER.md) — Adapters, Repositories
- [UI Layer](UI_LAYER.md) — Views, ViewModels, Presenters
