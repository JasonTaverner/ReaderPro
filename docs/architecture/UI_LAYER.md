# UI Layer

SwiftUI-based input adapter. Views are declarative and contain no business logic. Presenters coordinate with Use Cases. ViewModels hold UI-only state.

## Directory Structure

```
UI/
├── Presenters/
│   ├── ProjectListPresenter.swift
│   ├── EditorPresenter.swift
│   ├── PlayerPresenter.swift
│   └── SettingsPresenter.swift
├── ViewModels/
│   ├── ProjectListViewModel.swift
│   ├── EditorViewModel.swift
│   └── PlayerViewModel.swift
├── Views/
│   ├── ProjectListView.swift
│   ├── ProjectDetailView.swift      ← Main editor view
│   ├── CreateProjectView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── VoiceSelectorView.swift
│       ├── AccentSelectorView.swift
│       ├── EmotionSelectorView.swift
│       ├── VoiceCloneView.swift
│       ├── WaveformView.swift
│       ├── PlaybackControlsView.swift
│       └── AudioEntryCard.swift
└── Styles/
    └── (Custom button styles, color extensions)
```

## Pattern: Presenter → ViewModel → View

```
┌──────────┐     calls      ┌──────────────┐    reads     ┌──────────┐
│   View   │ ──────────────→│  Presenter   │              │ ViewModel│
│ (SwiftUI)│                │ (@MainActor) │──── writes──→│(@Publish)│
│          │←── observes ───│              │              │          │
└──────────┘                └──────────────┘              └──────────┘
                                   │
                              Use Cases
```

1. **Presenter** (`@MainActor`, `ObservableObject`) — Orchestrates use cases, updates ViewModel
2. **ViewModel** (`ObservableObject`) — Observable UI state via `@Published` properties
3. **View** (`struct`, `View`) — Reads ViewModel, calls Presenter methods on user events

### Nested ObservableObject Fix

SwiftUI doesn't propagate changes from nested `ObservableObject`s. Each presenter subscribes to its ViewModel's `objectWillChange`:

```swift
viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
    self?.objectWillChange.send()
}
```

## Presenters

### EditorPresenter

The largest presenter, coordinating project editing, audio generation, and playback.

**Dependencies (14 injected):**
- Use Cases: create, get, update, generateAudio, generateAudioForEntry, saveAudioEntry, captureAndProcess, processImageBatch, processDocument, mergeProject, processTextBatch
- Ports: ttsPort, audioPlayer, audioStorage
- Coordinator: ttsCoordinator

**Key methods:**

| Category | Methods |
|---|---|
| Lifecycle | `onAppear(projectId:)`, `loadProject()`, `loadVoices()` |
| Editing | `updateName()`, `updateText()`, `updateSpeed()`, `updatePitch()`, `selectVoice()` |
| Audio Gen | `generateAudio()`, `generateAudioForEntry(entryId:)` |
| Playback | `playEntry(_:)`, `stopPlayback()`, `togglePlayPause()`, `seek(to:)` |
| Navigation | `playNext()`, `playPrevious()`, `skipForward()`, `skipBackward()` |
| Import | `captureScreen()`, `importImages(_:)`, `importDocument(_:)`, `processTextBatch(_:)` |
| Export | `mergeProject(options:)` |
| Finder | `showInFinder()` |

**Auto-save:** Debounced at 2 seconds. Changes to name, text, voice, speed, or pitch trigger auto-save timer.

**Auto-play:** When an entry finishes playback, automatically plays the next entry if auto-play is enabled.

**Provider observation:** Subscribes to `TTSServerCoordinator.activeProviderPublisher` to reload voices when the user switches providers globally.

### ProjectListPresenter

Coordinates the project list screen.

**Key methods:**
- `onAppear()` — loads all projects
- `createProject(name:)` — creates empty project
- `deleteProject(id:)` — deletes with confirmation
- `search(query:)` — filters cached projects locally
- `generateAudio(for:)` — generates audio from list
- `setCoverImage(for:imageURL:)` — sets project cover
- `showInFinder(project:)` — opens project folder

### SettingsPresenter

Manages the Settings window.

**Features:**
- Storage directory configuration
- TTS memory management (check loaded model, free memory)
- Server status monitoring

## ViewModels

### EditorViewModel

```swift
class EditorViewModel: ObservableObject {
    // Project identity
    @Published var projectId: String?
    @Published var name: String
    @Published var isNewProject: Bool

    // Content
    @Published var text: String
    @Published var entries: [AudioEntryDTO]

    // Voice
    @Published var selectedVoiceId: String?
    @Published var availableVoices: [VoiceDTO]
    @Published var speed: Double
    @Published var pitch: Double

    // Qwen3-specific
    @Published var selectedEmotion: String
    @Published var customInstruct: String
    @Published var selectedAccent: String
    @Published var selectedGender: String
    @Published var voiceDesignCustom: String
    @Published var isCloneMode: Bool
    @Published var referenceAudioURL: URL?

    // Playback
    @Published var isPlaying: Bool
    @Published var currentTime: TimeInterval
    @Published var duration: TimeInterval
    @Published var waveformSamples: [Float]
    @Published var playingEntryId: String?
    @Published var isAutoPlayEnabled: Bool
    @Published var playbackSpeed: Float

    // Status
    @Published var isLoading: Bool
    @Published var isGenerating: Bool
    @Published var isCapturing: Bool
    @Published var isImporting: Bool
    @Published var error: String?
    @Published var autoSaveStatus: AutoSaveStatus
}
```

### ProjectListViewModel

```swift
class ProjectListViewModel: ObservableObject {
    @Published var projects: [ProjectSummary]
    @Published var isLoading: Bool
    @Published var error: String?
    @Published var searchQuery: String
    @Published var isGeneratingAudio: Bool
    @Published var generatingProjectId: String?
    @Published var thumbnailFullPaths: [String: String]

    var hasProjects: Bool       // Computed
    var showEmptyState: Bool    // Computed
    var showNoResults: Bool     // Computed
}
```

## Views

### ProjectListView

Main window with `NavigationStack` and typed destinations.

```swift
enum Destination: Hashable {
    case create
    case detail(Identifier<Project>)
}
```

Features: search bar, project grid, context menus (delete, show in Finder), create button.

### ProjectDetailView

Two-column layout for project editing.

**Left column (ScrollView):**
- Text editor with character count
- Entry grid (`LazyVGrid` of `AudioEntryCard`)
- Audio player section (waveform, controls, speed selector)

**Right sidebar (280pt):**
- Project name
- Voice selector
- Qwen3 controls (accent, emotion, voice clone) — conditional
- Speed/pitch sliders
- Action buttons (save, capture, import, generate, export, show in Finder)

**Bindings pattern:** Views create `Binding(get:set:)` proxies that call presenter methods:

```swift
private var nameBinding: Binding<String> {
    Binding(
        get: { presenter.viewModel.name },
        set: { presenter.updateName($0) }
    )
}
```

**Mutual exclusivity:** Accent selection and voice cloning are mutually exclusive. Selecting an accent clears clone mode, and enabling clone mode clears the accent.

### CreateProjectView

Simple form with project name input. On creation, navigates to `ProjectDetailView`.

### SettingsView

macOS Settings window (500x350pt) with storage directory and TTS memory sections.

## Components

### VoiceSelectorView
Menu picker for available voices, shows metadata (provider, language).

### AccentSelectorView
Horizontal chip buttons for `VoiceAccent` cases with flag emojis. Shows gender selector when accent selected.

### EmotionSelectorView
Horizontal chip buttons for `SpeechEmotion` cases. Includes custom instruction text field.

### VoiceCloneView
Toggle + file picker for reference audio. Validates minimum 3-second duration.

### WaveformView
Canvas-based amplitude visualization with drag-to-seek. Colored bars show playback progress.

### PlaybackControlsView
Play/pause, skip forward/backward (10s), time display.

### AudioEntryCard
Displays entry text preview, image thumbnail, and play/generate buttons.

## Navigation

```
ReaderProApp
  └── WindowGroup
       └── ProjectListView (NavigationStack)
            ├── .create → CreateProjectView
            └── .detail(id) → ProjectDetailView
  └── Settings
       └── SettingsView
```

Entry point: `ReaderProApp` uses `DependencyContainer.shared` to create presenters. Dark theme enforced. Minimum window: 800x600.
