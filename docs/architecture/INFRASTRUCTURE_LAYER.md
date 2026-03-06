# Infrastructure Layer

The outermost layer. Implements ports defined in Domain with concrete adapters using system frameworks and external services.

## Directory Structure

```
Infrastructure/
├── Adapters/
│   ├── TTS/
│   │   ├── KokoroTTSAdapter.swift          # Remote Kokoro server
│   │   ├── Qwen3TTSAdapter.swift           # Qwen3-TTS (MLX server)
│   │   ├── TTSAdapterProxy.swift           # Runtime switching proxy
│   │   ├── TTSServerCoordinator.swift      # Server lifecycle manager
│   │   ├── TTSServerStatus.swift           # Shared status enum
│   │   ├── KokoroServerManager.swift       # Python server launcher
│   │   ├── Qwen3ServerManager.swift        # MLX server launcher
│   │   └── KokoroONNX/                     # Local ONNX inference
│   │       ├── KokoroONNXAdapter.swift
│   │       ├── KokoroONNXEngine.swift
│   │       ├── EspeakPhonemizer.swift
│   │       ├── KokoroTokenizer.swift
│   │       ├── VoiceEmbeddingStore.swift
│   │       ├── AudioTrimmer.swift
│   │       ├── WAVEncoder.swift
│   │       └── NpyParser.swift
│   ├── Audio/
│   │   ├── AVAudioPlayerAdapter.swift      # AudioPlayerPort impl
│   │   └── AVFoundationEditorAdapter.swift # AudioEditorPort impl
│   ├── Persistence/
│   │   ├── FileSystemProjectRepository.swift
│   │   ├── FileSystemAudioStorage.swift
│   │   ├── ProjectMapper.swift
│   │   └── ProjectJSON.swift
│   ├── DocumentProcessing/
│   │   ├── VisionOCRAdapter.swift
│   │   ├── PDFParserAdapter.swift
│   │   ├── EPUBParserAdapter.swift
│   │   ├── ScreenCaptureService.swift
│   │   └── PDFKitGeneratorAdapter.swift
│   └── Translation/
│       └── (future adapters)
└── Configuration/
    └── StorageConfiguration.swift
```

## TTS Adapters

### TTSAdapterProxy

Thread-safe proxy that delegates to the currently active TTS adapter. All use cases reference this proxy instead of concrete adapters.

```swift
final class TTSAdapterProxy: TTSPort {
    private var current: TTSPort
    private let lock = NSLock()

    func switchAdapter(_ adapter: TTSPort)  // Called by coordinator
}
```

### TTSServerCoordinator

Manages the lifecycle of TTS servers and coordinates provider switching.

**Responsibilities:**
- Starts/stops Kokoro and Qwen3 servers
- Switches the active provider via `TTSAdapterProxy`
- Publishes `activeProvider` changes via Combine
- Manages `KokoroMode` (`.localONNX` vs `.remoteServer`)

**Key properties:**
- `activeProvider: Voice.TTSProvider` — current provider
- `kokoroMode: KokoroMode` — local ONNX or remote server
- `serverStatus: TTSServerStatus` — online/offline/starting/error

### KokoroTTSAdapter

Communicates with the Python Kokoro server at `localhost:8880`.

**Endpoint:** `POST /synthesize`
- Request body: `{ "text": "...", "voice": "af_bella", "speed": 1.0 }`
- Response: WAV binary data

### Qwen3TTSAdapter

Communicates with the MLX-based Qwen3-TTS server at `localhost:8890`.

**Endpoints:**
- `POST /synthesize` — CustomVoice or VoiceDesign mode
- `POST /clone` — Voice cloning with reference audio (multipart form data)

**Modes determined by VoiceConfiguration:**
- `voiceDesignInstruct != nil` → VoiceDesign mode (for Spanish, French, etc.)
- `referenceAudioURL != nil` → Voice cloning mode
- Otherwise → CustomVoice mode (9 premium voices)

**9 Premium Voices:** Chelsie, Aidan, Luna, Mia, Josh, Elena, Aria, Marcus, Zara

### KokoroONNXAdapter (Local Inference)

Full native TTS inference pipeline without any server. See [TTS: Kokoro](../features/TTS_KOKORO.md) for details.

**Pipeline:**
```
Text → EspeakPhonemizer → KokoroTokenizer → KokoroONNXEngine → AudioTrimmer → WAVEncoder
```

### Server Managers

**KokoroServerManager** — Launches `kokoro_server.py` via Python subprocess, monitors health at `/health`.

**Qwen3ServerManager** — Launches `qwen3_mlx_server.py` via Python subprocess, monitors health at `/health`.

Both managers:
- Search multiple paths for scripts (Bundle, SOURCE_ROOT, relative paths)
- Auto-detect Python interpreter
- Monitor process lifecycle
- Report status via `TTSServerStatus`

## Persistence

### FileSystemProjectRepository

Implements `ProjectRepositoryPort` using the filesystem.

**Storage layout:**
```
~/Documents/ReaderProLibrary/
├── {ProjectName}/
│   ├── project.json       ← Project metadata
│   ├── 001.txt            ← Entry text
│   ├── 001.wav            ← Entry audio
│   ├── 001.png            ← Entry image (optional)
│   ├── 002.txt
│   ├── 002.wav
│   └── cover.png          ← Project cover image
```

**project.json schema:**
```json
{
  "id": "uuid-string",
  "name": "Project Name",
  "text": "Optional main text",
  "voice_id": "af_bella",
  "voice_name": "Bella",
  "voice_language": "en-US",
  "voice_provider": "kokoro",
  "speed": 1.0,
  "pitch": 1.0,
  "status": "ready",
  "entries": [
    {
      "id": "entry-uuid",
      "text": "Entry text content",
      "audio_path": "001.wav",
      "image_path": "001.png",
      "created_at": 1234567890.0
    }
  ],
  "cover_image_path": "cover.png",
  "created_at": 1234567890.0,
  "updated_at": 1234567890.0
}
```

### FileSystemAudioStorage

Manages audio file I/O within project directories.

**Properties:**
- `baseDirectory: String` — root storage path

**Methods:**
- Save audio data as numbered WAV files
- Load audio from path
- Delete audio files
- Export in different formats

### ProjectMapper / ProjectJSON

Bidirectional mapping between domain `Project` objects and JSON persistence.

- `ProjectJSON` — `Codable` struct with snake_case keys
- `AudioEntryJSON` — nested entries
- `ProjectMapper` — converts between domain and JSON types

## Audio Adapters

### AVAudioPlayerAdapter

Implements `AudioPlayerPort` using `AVAudioPlayer`.

**Features:**
- Load, play, pause, stop, seek
- Variable playback rate
- Waveform sample generation (reads PCM buffer, computes peak amplitudes)
- Playback completion callback for auto-play

### AVFoundationEditorAdapter

Implements `AudioEditorPort` using `AVFoundation`.

**Operations:**
- Trim audio to time range
- Merge multiple audio files
- Adjust playback speed
- Adjust volume
- Fade in/out effects

## Document Processing

### VisionOCRAdapter

Implements `OCRPort` using Apple Vision framework.

**Capabilities:**
- OCR from image data (CGImage)
- OCR from PDF pages (rendered at 300dpi)
- Screen capture OCR (via SCScreenshotManager)
- Supported languages: ES, EN, FR, DE, PT, IT
- Recognition level: `.accurate` with language correction

### PDFParserAdapter

Implements `DocumentParserPort` for PDF files using PDFKit.

### ScreenCaptureService

Interactive screenshot capture using macOS screen capture APIs.

## Configuration

### StorageConfiguration

Manages the base storage directory with security-scoped bookmark support.

**Features:**
- Default: `~/Documents/ReaderProLibrary/`
- Custom directory via NSOpenPanel
- Security-scoped bookmarks for sandboxed access
- Stale bookmark auto-renewal
