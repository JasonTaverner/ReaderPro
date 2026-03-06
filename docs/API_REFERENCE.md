# API Reference

Internal API documentation for ReaderPro's TTS servers and domain interfaces.

## TTS Server APIs

### Kokoro Server (localhost:8880)

#### POST /synthesize

Generate audio from text.

**Request:**
```json
{
  "text": "Hello, this is a test.",
  "voice": "af_bella",
  "speed": 1.0
}
```

**Response:** `200 OK` with `Content-Type: audio/wav`

Binary WAV data (24kHz, mono, 16-bit).

**Errors:**
- `400` — Missing required fields
- `500` — Synthesis failed

#### GET /health

**Response:**
```json
{
  "status": "ok"
}
```

---

### Qwen3-TTS Server (localhost:8890)

#### POST /synthesize

Generate audio using CustomVoice or VoiceDesign mode.

**Request (CustomVoice):**
```json
{
  "text": "Hello, this is a test.",
  "speaker": "Chelsie",
  "mode": "custom_voice",
  "lang_code": "auto",
  "instruct": "Speak with a happy tone"
}
```

**Request (VoiceDesign):**
```json
{
  "text": "Hola, esto es una prueba.",
  "speaker": "Chelsie",
  "mode": "voice_design",
  "voice_design_instruct": "Describe a woman around 30 years old with a warm, clear female voice. She speaks with a native Castilian Spanish accent.",
  "voice_design_language": "es"
}
```

**Response:** `200 OK` with `Content-Type: audio/wav`

Binary WAV data.

**Parameters:**

| Field | Type | Required | Description |
|---|---|---|---|
| `text` | string | yes | Text to synthesize |
| `speaker` | string | no | Voice name (CustomVoice mode) |
| `mode` | string | no | `custom_voice` or `voice_design` |
| `lang_code` | string | no | Language code (`auto`, `es`, `fr`, etc.) |
| `instruct` | string | no | Style instruction (CustomVoice) |
| `voice_design_instruct` | string | no | Voice description (VoiceDesign) |
| `voice_design_language` | string | no | Language code for VoiceDesign |

#### POST /clone

Clone a voice from reference audio.

**Request:** `multipart/form-data`

| Field | Type | Description |
|---|---|---|
| `audio` | file | Reference audio (WAV/MP3, min 3s) |
| `text` | string | Text to synthesize |

**Response:** `200 OK` with `Content-Type: audio/wav`

#### POST /unload

Free model memory.

**Response:**
```json
{
  "status": "ok",
  "message": "Model unloaded"
}
```

#### GET /health

**Response:**
```json
{
  "status": "ok",
  "loaded_model": "custom_voice",
  "memory_used_mb": 4096
}
```

---

## Domain Ports (Swift Protocols)

### TTSPort

```swift
protocol TTSPort {
    var isAvailable: Bool { get async }
    var provider: Voice.TTSProvider { get }
    func availableVoices() async -> [Voice]
    func synthesize(
        text: TextContent,
        voiceConfiguration: VoiceConfiguration,
        voice: Voice
    ) async throws -> AudioData
}
```

### ProjectRepositoryPort

```swift
protocol ProjectRepositoryPort {
    func save(_ project: Project) async throws
    func findById(_ id: Identifier<Project>) async throws -> Project?
    func findAll() async throws -> [Project]
    func search(query: String) async throws -> [Project]
    func delete(_ id: Identifier<Project>) async throws
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
    var rate: Float { get async }
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

### AudioStoragePort

```swift
protocol AudioStoragePort {
    var baseDirectory: String { get }
    func save(audio: AudioData, projectName: String, entryNumber: Int) async throws -> String
    func load(path: String) async throws -> AudioData
    func delete(path: String) async throws
}
```

### OCRPort

```swift
protocol OCRPort {
    var isAvailable: Bool { get }
    func recognizeText(from imageData: ImageData) async throws -> RecognizedText
    func recognizeText(from pdfPath: String, pageNumber: Int) async throws -> RecognizedText
    func recognizeText(from pdfPath: String) async throws -> [RecognizedText]
}
```

### AudioEditorPort

```swift
protocol AudioEditorPort {
    func trim(audioPath: String, range: TimeRange) async throws -> String
    func merge(audioPaths: [String]) async throws -> String
    func adjustSpeed(audioPath: String, rate: Double) async throws -> String
    func adjustVolume(audioPath: String, factor: Double) async throws -> String
}
```

---

## Use Case Protocols

### CreateProjectUseCaseProtocol
```swift
func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse
```

### GenerateAudioUseCaseProtocol
```swift
func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse
```

### GenerateAudioForEntryUseCaseProtocol
```swift
func execute(_ request: GenerateAudioForEntryRequest) async throws -> GenerateAudioForEntryResponse
```

### GetProjectUseCaseProtocol
```swift
func execute(_ request: GetProjectRequest) async throws -> GetProjectResponse
```

### UpdateProjectUseCaseProtocol
```swift
func execute(_ request: UpdateProjectRequest) async throws -> UpdateProjectResponse
```

### DeleteProjectUseCaseProtocol
```swift
func execute(_ request: DeleteProjectRequest) async throws -> DeleteProjectResponse
```

### ListProjectsUseCaseProtocol
```swift
func execute(_ request: ListProjectsRequest) async throws -> ListProjectsResponse
```

### SaveAudioEntryUseCaseProtocol
```swift
func execute(_ request: SaveAudioEntryRequest) async throws -> SaveAudioEntryResponse
```
