# Domain Layer

The innermost layer. Contains business rules, entities, value objects, ports, and domain events. **No external framework dependencies** — pure Swift only.

## Directory Structure

```
Domain/
├── AudioGeneration/
│   ├── Entities/
│   │   └── Voice.swift
│   ├── Ports/
│   │   └── TTSPort.swift
│   └── ValueObjects/
│       ├── AudioData.swift
│       ├── SpeechEmotion.swift
│       ├── Text.swift (TextContent)
│       ├── VoiceAccent.swift
│       └── VoiceConfiguration.swift
├── ProjectManagement/
│   ├── Entities/
│   │   ├── AudioEntry.swift
│   │   └── Project.swift          ← Aggregate Root
│   ├── Events/
│   │   ├── DomainEvent.swift
│   │   ├── ProjectCreatedEvent.swift
│   │   ├── ProjectRenamedEvent.swift
│   │   ├── ProjectTextUpdatedEvent.swift
│   │   ├── ProjectDeletedEvent.swift
│   │   ├── AudioGeneratedEvent.swift
│   │   ├── EntryAddedEvent.swift
│   │   ├── EntryRemovedEvent.swift
│   │   └── EntryUpdatedEvent.swift
│   ├── Ports/
│   │   └── ProjectRepositoryPort.swift
│   └── ValueObjects/
│       ├── ProjectName.swift
│       ├── ProjectStatus.swift
│       ├── ProjectId.swift
│       └── EntryId.swift
├── AudioEditing/
│   ├── Entities/
│   │   └── AudioSegment.swift
│   ├── Ports/
│   │   ├── AudioEditorPort.swift
│   │   └── AudioPlayerPort.swift
│   └── ValueObjects/
│       └── TimeRange.swift
├── DocumentProcessing/
│   ├── Ports/
│   │   ├── OCRPort.swift
│   │   ├── DocumentParserPort.swift
│   │   ├── PDFGeneratorPort.swift
│   │   └── ScreenCapturePort.swift
│   └── ValueObjects/
│       ├── CapturedImage.swift
│       ├── DocumentSection.swift
│       ├── ImageData.swift
│       └── RecognizedText.swift
├── Translation/
│   ├── Ports/
│   │   └── TranslationPort.swift
│   └── ValueObjects/
│       └── TranslatedText.swift
└── Shared/
    ├── Errors/
    │   └── DomainError.swift
    └── ValueObjects/
        ├── AudioFormat.swift
        ├── AudioQuality.swift
        ├── Identifier.swift
        └── Identifier+Identifiable.swift
```

## Value Objects

Immutable (`struct` with `let`), validated at construction, compared by value.

### Identifier\<T\>

Generic type-safe identifier preventing cross-entity ID confusion.

```swift
struct Identifier<T>: Equatable, Hashable, Codable, CustomStringConvertible {
    let value: UUID

    init()              // Auto-generates UUID
    init(_ value: UUID) // Reconstitution from persistence
}

typealias ProjectId = Identifier<Project>
typealias EntryId   = Identifier<AudioEntry>
```

### TextContent

Validated text with business rules.

```swift
struct TextContent: Equatable {
    let value: String

    init(_ value: String) throws  // Non-empty, max 6000 chars

    var wordCount: Int             // Computed
    var estimatedDuration: TimeInterval  // ~150 words/minute
}
```

### ProjectName

```swift
struct ProjectName: Equatable {
    let value: String

    init(_ value: String) throws  // Non-empty after trim, max 100 chars

    static func fromText(_ text: TextContent) -> ProjectName  // First 50 chars
}
```

### VoiceConfiguration

```swift
struct VoiceConfiguration: Equatable {
    let voiceId: String
    let speed: Speed                    // 0.5–2.0x
    let pitch: Pitch                    // 0.5–2.0x
    let instruct: String?              // Style instruction (Qwen3)
    let referenceAudioURL: URL?        // Voice cloning reference
    let voiceDesignInstruct: String?   // VoiceDesign mode instruct
    let voiceDesignLanguage: String?   // Language code (es, fr, de...)
}
```

### AudioData

```swift
struct AudioData: Equatable {
    let data: Data              // Audio bytes
    let duration: TimeInterval  // Seconds

    var sizeInBytes: Int
    var sizeInKB: Double
    var sizeInMB: Double
}
```

### ProjectStatus

```swift
enum ProjectStatus: String, Equatable, CaseIterable {
    case draft       // No audio generated
    case generating  // In progress
    case ready       // Audio available
    case error       // Generation failed

    var isProcessing: Bool
    var hasAudio: Bool
    var canRegenerate: Bool
}
```

### SpeechEmotion

```swift
enum SpeechEmotion: String, CaseIterable, Equatable {
    case neutral, happy, sad, angry, whisper, excited, calm, fearful

    var displayName: String
    var instruct: String?  // nil for neutral
}
```

### VoiceAccent & VoiceGender

Used for Qwen3 VoiceDesign mode (languages without native CustomVoice).

```swift
enum VoiceGender: String, CaseIterable { case male, female }

enum VoiceAccent: String, CaseIterable {
    case spanishSpain, spanishMexico, spanishArgentina
    case french, german, italian
    case portugueseBrazil, portuguesePortugal
    case russian

    var languageCode: String   // es, fr, de, it, pt, ru
    var flag: String           // Flag emoji

    func voiceDesignInstruct(gender: VoiceGender, style emotion: String?) -> String
}
```

## Entities

Have identity (unique `id`), mutable state.

### Voice

```swift
struct Voice: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let language: String
    let provider: TTSProvider
    let isDefault: Bool

    enum TTSProvider: String, CaseIterable {
        case native   // AVSpeechSynthesizer
        case kokoro   // Kokoro TTS (local or server)
        case qwen3    // Qwen3-TTS
    }
}
```

### AudioEntry

Child entity of the `Project` aggregate.

```swift
struct AudioEntry: Equatable, Hashable, Identifiable {
    let id: EntryId
    let text: TextContent
    var audioPath: String?
    var imagePath: String?
    let createdAt: Date

    var hasAudio: Bool
    var hasImage: Bool

    mutating func setAudioPath(_ path: String)
    mutating func setImagePath(_ path: String)
}
```

## Aggregate Root — Project

The central aggregate that enforces all business invariants.

```swift
final class Project {
    // Identity & metadata
    private(set) var id: ProjectId
    private(set) var name: ProjectName
    private(set) var text: TextContent?
    private(set) var status: ProjectStatus
    private(set) var createdAt: Date
    private(set) var updatedAt: Date

    // Voice
    private(set) var voiceConfiguration: VoiceConfiguration
    private(set) var voice: Voice

    // Audio
    private(set) var audioPath: String?
    private(set) var entries: [AudioEntry]
    private(set) var coverImagePath: String?

    // Events
    private(set) var domainEvents: [DomainEvent]
}
```

**Key behaviors:**

| Method | Effect |
|---|---|
| `updateText(_:)` | Invalidates audio, sets status to `.draft`, emits event |
| `rename(_:)` | Updates name without invalidating audio |
| `updateVoiceConfiguration(_:)` | Invalidates audio |
| `markGenerating()` | Sets status to `.generating` |
| `markAudioGenerated(path:)` | Sets status to `.ready`, emits `AudioGeneratedEvent` |
| `markError()` | Sets status to `.error` |
| `addEntry(_:)` | Adds child entry, emits `EntryAddedEvent` |
| `removeEntry(id:)` | Removes entry, emits `EntryRemovedEvent` |
| `updateEntry(_:)` | Updates entry, emits `EntryUpdatedEvent` |
| `setCoverImage(path:)` | Sets cover image path |
| `clearEvents()` | Clears accumulated domain events |

## Ports (Interfaces)

Contracts that infrastructure must implement. Defined here in Domain so they depend on nothing external.

### TTSPort

```swift
protocol TTSPort {
    var isAvailable: Bool { get async }
    var provider: Voice.TTSProvider { get }

    func availableVoices() async -> [Voice]
    func synthesize(text: TextContent, voiceConfiguration: VoiceConfiguration, voice: Voice) async throws -> AudioData
}
```

### ProjectRepositoryPort

```swift
protocol ProjectRepositoryPort {
    func save(_ project: Project) async throws
    func findById(_ id: ProjectId) async throws -> Project?
    func findAll() async throws -> [Project]
    func search(query: String) async throws -> [Project]
    func delete(_ id: ProjectId) async throws
    func findByStatus(_ status: ProjectStatus) async throws -> [Project]
    func findCreatedAfter(_ date: Date) async throws -> [Project]
}
```

### AudioPlayerPort

```swift
protocol AudioPlayerPort {
    var isPlaying: Bool { get async }
    var currentTime: TimeInterval { get async }
    var duration: TimeInterval { get async }
    var onPlaybackComplete: (() -> Void)? { get set }

    func load(path: String) async throws
    func play() async
    func pause() async
    func stop() async
    func seek(to time: TimeInterval) async
    func setRate(_ rate: Float) async
    func generateWaveformSamples(sampleCount: Int) async throws -> [Float]
}
```

### Other Ports

- **`AudioEditorPort`** — trim, merge, adjustSpeed, adjustVolume, fadeIn, fadeOut
- **`AudioStoragePort`** — save, load, delete, export audio files
- **`OCRPort`** — recognizeText from images and PDFs
- **`DocumentParserPort`** — extractPages from PDF/EPUB
- **`ScreenCapturePort`** — captureInteractive, captureRegion
- **`PDFGeneratorPort`** — generate PDFs from images
- **`TranslationPort`** — translate text between languages

## Domain Events

Events emitted by the `Project` aggregate on state changes.

| Event | Triggered By |
|---|---|
| `ProjectCreatedEvent` | `Project.init()` |
| `ProjectRenamedEvent` | `rename(_:)` |
| `ProjectTextUpdatedEvent` | `updateText(_:)` |
| `ProjectDeletedEvent` | Repository delete |
| `AudioGeneratedEvent` | `markAudioGenerated(path:)` |
| `EntryAddedEvent` | `addEntry(_:)` |
| `EntryRemovedEvent` | `removeEntry(id:)` |
| `EntryUpdatedEvent` | `updateEntry(_:)` |

## Errors

```swift
enum DomainError: Error, Equatable {
    case invalidText(String)
    case invalidProjectName(String)
    case invalidSpeed
    case invalidPitch
    case invalidTimeRange(String)
    case invalidAudioDuration(String)
    case emptyAudioData
    case emptyImageData
    case emptyRecognizedText
    case segmentsOverlap
    case projectNotFound
    case entryNotFound
    // ... more cases
}
```

All error messages are localized in Spanish via `localizedDescription`.
