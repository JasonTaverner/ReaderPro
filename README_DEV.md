# ReaderPro — Developer Guide

This document covers the architecture, project structure, coding conventions, and development workflow for contributors.

## Architecture

ReaderPro uses **Domain-Driven Design (DDD)** with **Hexagonal Architecture** (Ports & Adapters) and follows **TDD** (Test-Driven Development).

```
┌─────────────────────────────────────────────────────────────┐
│                      INFRASTRUCTURE                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    APPLICATION                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │                   DOMAIN                         │  │  │
│  │  │  Entities, Value Objects, Domain Services,       │  │  │
│  │  │  Aggregates, Domain Events, Ports (Interfaces)   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  Use Cases, Application Services, DTOs                │  │
│  └───────────────────────────────────────────────────────┘  │
│  Adapters: SwiftUI, SwiftData, AVFoundation, ONNX, MLX     │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Rule

Dependencies always point **inward**:

```
UI (SwiftUI) → Application (Use Cases) → Domain (Pure Swift) ← Infrastructure (Adapters)
```

- **Domain** — Zero external imports. Pure Swift types.
- **Application** — Depends only on Domain. Orchestrates use cases.
- **Infrastructure** — Implements Domain ports with real frameworks.
- **UI** — SwiftUI views call use cases through presenters.

## Project Structure

```
ReaderPro/
├── App/                              # Entry point & DI container
├── Domain/                           # Pure business logic
│   ├── AudioGeneration/              # TTS voices, synthesis
│   │   ├── Entities/Voice.swift
│   │   ├── ValueObjects/             # Text, VoiceConfiguration, AudioData, SpeechEmotion
│   │   ├── Ports/TTSPort.swift
│   │   └── Services/
│   ├── AudioEditing/                 # Segments, time ranges, effects
│   ├── ProjectManagement/            # Project aggregate, entries
│   ├── DocumentProcessing/           # OCR, PDF, EPUB, screenshots
│   ├── Translation/                  # Translation port (interface only)
│   ├── ClipboardAndHotkeys/          # Clipboard, global hotkeys
│   └── Shared/                       # Identifier, DomainError
│
├── Application/                      # Use cases & DTOs
│   ├── UseCases/
│   │   ├── GenerateAudio/
│   │   ├── ManageProjects/
│   │   ├── DocumentProcessing/
│   │   ├── MergeProject/
│   │   └── Playback/
│   ├── Services/
│   └── DTOs/
│
├── Infrastructure/                   # Adapters (framework-dependent)
│   └── Adapters/
│       ├── TTS/
│       │   ├── NativeTTSAdapter.swift
│       │   ├── KokoroTTSAdapter.swift
│       │   ├── KokoroONNX/           # Built-in ONNX engine
│       │   └── Qwen3TTSAdapter.swift
│       ├── Persistence/FileSystem/
│       ├── Audio/AVFoundation*/
│       ├── DocumentProcessing/       # VisionOCR, PDFKit, EPUB, Screenshot
│       └── Security/Keychain
│
├── UI/                               # SwiftUI layer
│   ├── Presenters/                   # Coordinate with use cases
│   ├── ViewModels/                   # UI state only
│   ├── Views/                        # SwiftUI views
│   └── Navigation/
│
└── Tests/
    ├── Domain/
    ├── Application/
    ├── Infrastructure/
    └── Mocks/
```

## Bounded Contexts

| Context | Description | Status |
|:---|:---|:---:|
| Audio Generation | TTS synthesis (Qwen3, Kokoro, Native) | ✅ |
| Audio Editing | Trim, merge, speed, effects | ✅ |
| Project Management | CRUD, folders, merge/export | ✅ |
| Document Processing | OCR, PDF, EPUB, screenshots | ✅ |
| Playback | Audio player with waveform | ✅ |
| Translation | Text translation | Port only |
| Clipboard & Hotkeys | System integration | ✅ |

## Coding Conventions

### Naming

| Type | Convention | Example |
|:---|:---|:---|
| Entity | PascalCase | `Project`, `Voice` |
| Value Object | PascalCase | `Text`, `ProjectName`, `TimeRange` |
| Port | Suffix `Port` | `TTSPort`, `ProjectRepositoryPort` |
| Adapter | Suffix `Adapter` | `NativeTTSAdapter`, `VisionOCRAdapter` |
| Use Case | Suffix `UseCase` | `GenerateAudioUseCase` |
| Test | Suffix `Tests` | `ProjectTests` |

### Test Naming

```swift
func test_[method]_[condition]_[expected]()

// Examples:
func test_createText_withEmptyString_shouldThrow()
func test_generateAudio_withValidProject_shouldReturnAudioData()
```

### Test Pattern (AAA)

```swift
func test_example() {
    // Arrange
    let input = "test"

    // Act
    let result = sut.process(input)

    // Assert
    XCTAssertEqual(result, expected)
}
```

## TDD Workflow

```
🔴 RED      → Write a failing test
🟢 GREEN    → Minimum code to pass
🔵 REFACTOR → Improve while keeping tests green
```

## Build & Test

```bash
# Build
xcodebuild -scheme ReaderPro -configuration Debug build

# Run tests
xcodebuild -scheme ReaderPro -configuration Debug test

# Archive for distribution
xcodebuild -scheme ReaderPro -configuration Release archive
```

## File Persistence Layout

Projects are stored on the filesystem:

```
~/Documents/KokoroLibrary/
├── General/                  # Default project
│   ├── 001.txt               # Captured text (with metadata header)
│   ├── 001.wav               # Generated audio
│   ├── 001.png               # Associated screenshot (optional)
│   └── exports/              # Merge output
│       ├── merged.txt
│       ├── merged.wav
│       └── images.pdf
├── My_Book/
│   ├── 001.txt
│   ├── 001.wav
│   └── ...
```

Files are numbered sequentially (`001`, `002`, ...). Text, audio, and image share the same ID.

## Requirements

- macOS 14.0+ (Sonoma) — required for SwiftData
- Xcode 15.0+
- Swift 5.9+
- Apple Silicon recommended (Intel supported)

## Key Domain Rules

- Domain layer has **no framework imports** (only Swift stdlib)
- Value Objects are **immutable** (`struct` with `let`)
- Entities have **identity** (unique `id`)
- Aggregates protect their **invariants**
- Business logic lives in the **Domain**, not in use cases
