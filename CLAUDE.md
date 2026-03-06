# TextToAudio - Aplicación macOS (ReaderPro)

## Descripción del Proyecto
Aplicación nativa de macOS para convertir texto a audio, almacenar las conversiones y editarlas. Preparada para publicación en la Mac App Store.

## Archivos de Referencia

- `CLAUDE.md` - Este archivo (documentación principal)
- `README.md` - Guía de setup rápido
- `mac_reader_pro_V1.8.2.py` - Script Python original con funcionalidades a migrar
- `agents/` - Carpeta con agentes especializados:
  - `agents/main-agent.md` - Orquestador y roadmap
  - `agents/architecture-agent.md` - DDD, Hexagonal, TDD
  - `agents/audio-agent.md` - TTS y audio (Kokoro, Qwen3)
  - `agents/infrastructure-agent.md` - Persistencia y adapters
  - `agents/ui-agent.md` - SwiftUI y presenters

## Stack Tecnológico

### Lenguaje y Frameworks
- **Swift 5.9+** - Lenguaje principal
- **SwiftUI** - Framework de UI declarativo
- **SwiftData** - Persistencia de datos (requiere macOS 14+)
- **AVFoundation** - Reproducción y manipulación de audio
- **AVSpeechSynthesizer** - TTS nativo de Apple
- **Combine** - Programación reactiva
- **XCTest** - Testing unitario y de integración

### Arquitectura
- **DDD (Domain-Driven Design)** - Diseño guiado por el dominio
- **Arquitectura Hexagonal (Ports & Adapters)** - Separación clara entre dominio e infraestructura
- **TDD (Test-Driven Development)** - Desarrollo guiado por tests (Red-Green-Refactor)

### APIs de TTS Soportadas
1. **Nativo (AVSpeechSynthesizer)** - Sin coste, offline, calidad básica
2. **Kokoro** - TTS de alta calidad, open source, ejecutable localmente
3. **Qwen3-TTS** - TTS de Alibaba, muy natural, ejecutable localmente o via API

## Arquitectura Hexagonal + DDD

### Principios Fundamentales

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      APPLICATION                             │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │                     DOMAIN                           │   │   │
│  │  │                                                      │   │   │
│  │  │   Entities, Value Objects, Domain Services,         │   │   │
│  │  │   Aggregates, Domain Events, Ports (Interfaces)     │   │   │
│  │  │                                                      │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  │                                                             │   │
│  │   Use Cases, Application Services, DTOs, Port Impl.        │   │
│  │                                                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   Adapters: UI (SwiftUI), Persistence (SwiftData),                 │
│   External APIs (OpenAI, ElevenLabs), Audio (AVFoundation)         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Bounded Contexts
1. **Audio Generation** - Generación de audio desde texto (TTS)
2. **Audio Editing** - Edición y manipulación de audio
3. **Project Management** - Gestión de proyectos y persistencia
4. **Playback** - Reproducción de audio
5. **Document Processing** - OCR, procesamiento de PDF/EPUB, batch de imágenes
6. **Translation** - Traducción de texto entre idiomas
7. **Clipboard & Hotkeys** - Captura de portapapeles y atajos de teclado globales

## Estructura del Proyecto

```
TextToAudio/
├── App/
│   ├── TextToAudioApp.swift              # Entry point
│   ├── DependencyContainer.swift         # Composición de dependencias
│   └── AppDelegate.swift
│
├── Domain/                               # 🔴 NÚCLEO - Sin dependencias externas
│   ├── AudioGeneration/
│   │   ├── Entities/
│   │   │   └── Voice.swift               # Entity
│   │   ├── ValueObjects/
│   │   │   ├── Text.swift                # Value Object validado
│   │   │   ├── VoiceConfiguration.swift
│   │   │   └── AudioData.swift
│   │   ├── Ports/
│   │   │   └── TTSPort.swift             # Interface (Output Port)
│   │   ├── Services/
│   │   │   └── AudioGenerationService.swift  # Domain Service
│   │   └── Errors/
│   │       └── AudioGenerationError.swift
│   │
│   ├── AudioEditing/
│   │   ├── Entities/
│   │   │   └── AudioSegment.swift
│   │   ├── ValueObjects/
│   │   │   ├── TimeRange.swift
│   │   │   └── AudioEffect.swift
│   │   ├── Ports/
│   │   │   └── AudioEditorPort.swift
│   │   └── Services/
│   │       └── AudioEditingService.swift
│   │
│   ├── ProjectManagement/
│   │   ├── Entities/
│   │   │   ├── Project.swift             # Aggregate Root
│   │   │   └── AudioEntry.swift          # Entity (parte de Project)
│   │   ├── ValueObjects/
│   │   │   ├── ProjectId.swift
│   │   │   ├── ProjectName.swift
│   │   │   ├── EntryId.swift
│   │   │   └── ProjectStatus.swift
│   │   ├── Ports/
│   │   │   └── ProjectRepositoryPort.swift
│   │   ├── Services/
│   │   │   ├── ProjectDomainService.swift
│   │   │   └── MergeDomainService.swift  # Fusión de proyectos
│   │   └── Events/
│   │       ├── ProjectCreated.swift
│   │       ├── AudioGenerated.swift
│   │       └── ProjectMerged.swift
│   │
│   ├── DocumentProcessing/
│   │   ├── Entities/
│   │   │   ├── Document.swift
│   │   │   └── Page.swift
│   │   ├── ValueObjects/
│   │   │   ├── DocumentType.swift        # PDF, EPUB, Image
│   │   │   ├── PageImage.swift
│   │   │   ├── RecognizedText.swift
│   │   │   └── CapturedImage.swift
│   │   ├── Ports/
│   │   │   ├── OCRPort.swift
│   │   │   ├── DocumentParserPort.swift
│   │   │   └── ScreenshotPort.swift
│   │   └── Services/
│   │       ├── BatchProcessingService.swift
│   │       └── TextNormalizationService.swift
│   │
│   ├── Translation/
│   │   ├── ValueObjects/
│   │   │   ├── Language.swift
│   │   │   ├── TranslationText.swift
│   │   │   └── TranslatedText.swift
│   │   ├── Ports/
│   │   │   └── TranslationPort.swift
│   │   └── Errors/
│   │       └── TranslationError.swift
│   │
│   ├── ClipboardAndHotkeys/
│   │   ├── ValueObjects/
│   │   │   └── Hotkey.swift
│   │   ├── Ports/
│   │   │   ├── ClipboardPort.swift
│   │   │   └── HotkeyPort.swift
│   │   └── Errors/
│   │       └── HotkeyError.swift
│   │
│   └── Shared/
│       ├── ValueObjects/
│       │   └── Identifier.swift
│       └── Errors/
│           └── DomainError.swift
│
├── Application/                          # 🟡 CASOS DE USO
│   ├── UseCases/
│   │   ├── GenerateAudio/
│   │   │   ├── GenerateAudioUseCase.swift
│   │   │   ├── GenerateAudioFromTextUseCase.swift
│   │   │   ├── GenerateAudioFromScreenshotUseCase.swift
│   │   │   ├── GenerateAudioFromSelectionUseCase.swift
│   │   │   ├── GenerateAudioRequest.swift
│   │   │   └── GenerateAudioResponse.swift
│   │   ├── EditAudio/
│   │   │   ├── TrimAudioUseCase.swift
│   │   │   ├── MergeAudioUseCase.swift
│   │   │   ├── AdjustSpeedUseCase.swift
│   │   │   └── ApplyAudioFilterUseCase.swift
│   │   ├── ManageProjects/
│   │   │   ├── CreateProjectUseCase.swift
│   │   │   ├── ActivateProjectUseCase.swift
│   │   │   ├── GetProjectUseCase.swift
│   │   │   ├── ListProjectsUseCase.swift
│   │   │   ├── UpdateProjectUseCase.swift
│   │   │   ├── DeleteProjectUseCase.swift
│   │   │   ├── SaveAudioEntryUseCase.swift
│   │   │   ├── GetRecentEntriesUseCase.swift
│   │   │   └── MergeProjectUseCase.swift      # Crear Fusion_XXX
│   │   ├── DocumentProcessing/
│   │   │   ├── ProcessImageBatchUseCase.swift
│   │   │   ├── ProcessPDFToAudioUseCase.swift
│   │   │   ├── ProcessEPUBToAudioUseCase.swift
│   │   │   ├── CaptureScreenshotUseCase.swift
│   │   │   └── RecognizeTextUseCase.swift
│   │   ├── Translation/
│   │   │   ├── TranslateTextUseCase.swift
│   │   │   └── DetectLanguageUseCase.swift
│   │   └── Playback/
│   │       ├── PlayAudioUseCase.swift
│   │       ├── PauseAudioUseCase.swift
│   │       ├── StopAudioUseCase.swift
│   │       └── ExportAudioUseCase.swift
│   │
│   ├── Services/
│   │   └── ApplicationService.swift      # Orquestación
│   │
│   └── DTOs/
│       ├── ProjectDTO.swift
│       ├── VoiceDTO.swift
│       └── AudioDTO.swift
│
├── Infrastructure/                       # 🟢 ADAPTADORES
│   ├── Adapters/
│   │   ├── Persistence/
│   │   │   ├── SwiftData/
│   │   │   │   ├── Models/
│   │   │   │   │   ├── ProjectModel.swift
│   │   │   │   │   └── AudioSegmentModel.swift
│   │   │   │   ├── Mappers/
│   │   │   │   │   └── ProjectMapper.swift
│   │   │   │   └── SwiftDataProjectRepository.swift
│   │   │   └── FileSystem/
│   │   │       └── AudioFileStorage.swift
│   │   │
│   │   ├── TTS/
│   │   │   ├── NativeTTSAdapter.swift
│   │   │   ├── KokoroTTSAdapter.swift         # Kokoro local
│   │   │   ├── Qwen3TTSAdapter.swift          # Qwen3-TTS local
│   │   │   ├── OpenAITTSAdapter.swift
│   │   │   └── ElevenLabsTTSAdapter.swift
│   │   │
│   │   ├── Audio/
│   │   │   ├── AVFoundationPlayerAdapter.swift
│   │   │   ├── AVFoundationEditorAdapter.swift
│   │   │   ├── WaveformGeneratorAdapter.swift
│   │   │   └── AudioFilterAdapter.swift       # Filtros DSP (low-pass, etc.)
│   │   │
│   │   ├── DocumentProcessing/
│   │   │   ├── VisionOCRAdapter.swift         # Vision framework (OCR)
│   │   │   ├── PDFKitParserAdapter.swift      # PDF parsing
│   │   │   ├── EPUBParserAdapter.swift        # EPUB parsing
│   │   │   └── ScreenshotAdapter.swift        # Screenshot capture
│   │   │
│   │   ├── Translation/
│   │   │   ├── GoogleTranslationAdapter.swift
│   │   │   └── AppleTranslateAdapter.swift    # Translation framework
│   │   │
│   │   ├── Clipboard/
│   │   │   └── NSPasteboardAdapter.swift
│   │   │
│   │   ├── Hotkeys/
│   │   │   └── CGEventMonitorAdapter.swift
│   │   │
│   │   └── Security/
│   │       └── KeychainAdapter.swift
│   │
│   └── Configuration/
│       └── EnvironmentConfig.swift
│
├── UI/                                   # 🔵 ADAPTADOR DE ENTRADA (SwiftUI)
│   ├── Presenters/
│   │   ├── ProjectListPresenter.swift
│   │   ├── EditorPresenter.swift
│   │   ├── PlayerPresenter.swift
│   │   └── SettingsPresenter.swift
│   │
│   ├── ViewModels/                       # ViewModels simples (solo estado UI)
│   │   ├── ProjectListViewModel.swift
│   │   ├── EditorViewModel.swift
│   │   └── PlayerViewModel.swift
│   │
│   ├── Views/
│   │   ├── MainView.swift
│   │   ├── ProjectListView.swift
│   │   ├── EditorView.swift
│   │   ├── PlayerView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   │       ├── WaveformView.swift
│   │       ├── VoiceSelectorView.swift
│   │       └── PlaybackControlsView.swift
│   │
│   └── Navigation/
│       └── AppRouter.swift
│
├── Tests/
│   ├── Domain/
│   │   ├── AudioGeneration/
│   │   │   ├── VoiceTests.swift
│   │   │   ├── TextValueObjectTests.swift
│   │   │   └── AudioGenerationServiceTests.swift
│   │   ├── ProjectManagement/
│   │   │   ├── ProjectTests.swift
│   │   │   └── ProjectDomainServiceTests.swift
│   │   └── AudioEditing/
│   │       └── AudioSegmentTests.swift
│   │
│   ├── Application/
│   │   ├── GenerateAudioUseCaseTests.swift
│   │   ├── CreateProjectUseCaseTests.swift
│   │   └── TrimAudioUseCaseTests.swift
│   │
│   ├── Infrastructure/
│   │   ├── SwiftDataProjectRepositoryTests.swift
│   │   ├── NativeTTSAdapterTests.swift
│   │   └── AudioFileStorageTests.swift
│   │
│   ├── Integration/
│   │   ├── GenerateAndSaveProjectTests.swift
│   │   └── EditAndExportAudioTests.swift
│   │
│   ├── UI/
│   │   └── EditorPresenterTests.swift
│   │
│   └── Mocks/
│       ├── MockTTSPort.swift
│       ├── MockProjectRepository.swift
│       ├── MockAudioEditorPort.swift
│       └── TestFixtures.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

## Estructura de Persistencia del Proyecto

La aplicación almacena los proyectos en el sistema de archivos del usuario con la siguiente estructura:

```
~/Documents/KokoroLibrary/           # Directorio base (configurable)
├── General/                          # Proyecto por defecto
│   ├── 001.txt                       # Texto capturado (con metadata)
│   ├── 001.wav                       # Audio generado
│   ├── 001.png                       # Screenshot asociado (opcional)
│   ├── 002.txt
│   ├── 002.wav
│   ├── 002.png
│   │   ...
│   └── Fusion_001/                   # Carpeta de fusión (merge)
│       ├── documento_completo.txt    # Todos los textos concatenados
│       ├── audio_completo.wav        # Todos los audios unidos
│       └── imagenes.pdf              # Todas las imágenes en PDF
│
├── Libro_Quijote/                    # Proyecto personalizado
│   ├── 001.txt
│   ├── 001.wav
│   ├── 001.png
│   │   ...
│   ├── Fusion_001/
│   └── Fusion_002/
│
└── Tesis_Maestria/                   # Otro proyecto
    ├── 001.txt
    ├── 001.wav
    │   ...
```

### Formato de Archivos

**Archivo de texto (XXX.txt):**
```
--- Captura: 2024-01-15 14:30:45 ---

El contenido capturado va aquí.
Puede ser desde OCR, portapapeles, o texto manual.
```

**Archivo de audio (XXX.wav):**
- Formato: WAV
- Sample rate: 24000 Hz
- Canales: Mono
- Filtrado: Low-pass a 7500 Hz

**Archivo de imagen (XXX.png):**
- Formato: PNG
- Origen: Screenshot capturado o imagen procesada

**Carpetas de Fusión (Fusion_XXX/):**
- Se crean automáticamente al ejecutar "Merge"
- Contienen todos los archivos del proyecto concatenados/unidos
- Numeración secuencial (Fusion_001, Fusion_002, etc.)

### Reglas de Numeración

- Los archivos se numeran secuencialmente: `001`, `002`, `003`, etc.
- El sistema busca el número más alto existente y agrega `+1`
- Los tres archivos de una entrada comparten el mismo ID (texto, audio, imagen)
- Las carpetas de fusión siguen su propia secuencia: `Fusion_001`, `Fusion_002`, etc.

### Sincronización de Archivos

Para cada entrada guardada, el sistema crea:
1. **Siempre:** `XXX.txt` y `XXX.wav`
2. **Opcional:** `XXX.png` (si proviene de screenshot o imagen)

Los tres archivos se mantienen sincronizados por el ID numérico.

## Capas de la Arquitectura

### 1. Domain (Núcleo)
- **SIN dependencias externas** (ni Foundation si es posible, solo tipos Swift)
- Contiene la lógica de negocio pura
- Define Ports (interfaces) que serán implementados por adaptadores
- Completamente testeable sin mocks de infraestructura

### 2. Application (Casos de Uso)
- Orquesta el dominio
- Implementa los casos de uso de la aplicación
- Depende SOLO del dominio
- Define DTOs para comunicación con capas externas

### 3. Infrastructure (Adaptadores)
- Implementa los Ports definidos en el dominio
- Contiene todo el código "sucio": frameworks, APIs, persistencia
- Depende del dominio (implementa sus interfaces)

### 4. UI (Adaptador de Entrada)
- SwiftUI Views y Presenters
- Llama a los Use Cases
- NO contiene lógica de negocio

## Modelos de Dominio (DDD)

### Value Objects

```swift
// Domain/Shared/ValueObjects/Identifier.swift
struct Identifier<T>: Equatable, Hashable {
    let value: UUID
    
    init() {
        self.value = UUID()
    }
    
    init(_ value: UUID) {
        self.value = value
    }
}

typealias ProjectId = Identifier<Project>
typealias SegmentId = Identifier<AudioSegment>
```

```swift
// Domain/AudioGeneration/ValueObjects/Text.swift
struct Text: Equatable {
    let value: String
    
    init(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invalidText("El texto no puede estar vacío")
        }
        guard value.count <= 10000 else {
            throw DomainError.invalidText("El texto excede el límite de 10000 caracteres")
        }
        self.value = value
    }
    
    var wordCount: Int {
        value.split(separator: " ").count
    }
    
    var estimatedDuration: TimeInterval {
        // ~150 palabras por minuto
        TimeInterval(wordCount) / 150.0 * 60.0
    }
}
```

```swift
// Domain/ProjectManagement/ValueObjects/ProjectName.swift
struct ProjectName: Equatable {
    let value: String
    
    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.invalidProjectName("El nombre no puede estar vacío")
        }
        guard trimmed.count <= 100 else {
            throw DomainError.invalidProjectName("El nombre excede 100 caracteres")
        }
        self.value = trimmed
    }
    
    static func fromText(_ text: Text) -> ProjectName {
        let prefix = String(text.value.prefix(50))
        let cleaned = prefix.replacingOccurrences(of: "\n", with: " ")
        return try! ProjectName(cleaned.isEmpty ? "Nuevo proyecto" : cleaned)
    }
}
```

```swift
// Domain/AudioGeneration/ValueObjects/VoiceConfiguration.swift
struct VoiceConfiguration: Equatable {
    let voiceId: String
    let speed: Speed
    let pitch: Pitch
    
    struct Speed: Equatable {
        let value: Double
        
        init(_ value: Double) throws {
            guard (0.5...2.0).contains(value) else {
                throw DomainError.invalidSpeed
            }
            self.value = value
        }
        
        static let normal = try! Speed(1.0)
    }
    
    struct Pitch: Equatable {
        let value: Double
        
        init(_ value: Double) throws {
            guard (0.5...2.0).contains(value) else {
                throw DomainError.invalidPitch
            }
            self.value = value
        }
        
        static let normal = try! Pitch(1.0)
    }
}
```

```swift
// Domain/AudioEditing/ValueObjects/TimeRange.swift
struct TimeRange: Equatable {
    let start: TimeInterval
    let end: TimeInterval
    
    var duration: TimeInterval { end - start }
    
    init(start: TimeInterval, end: TimeInterval) throws {
        guard start >= 0 else {
            throw DomainError.invalidTimeRange("Start debe ser >= 0")
        }
        guard end > start else {
            throw DomainError.invalidTimeRange("End debe ser > start")
        }
        self.start = start
        self.end = end
    }
    
    func contains(_ time: TimeInterval) -> Bool {
        (start...end).contains(time)
    }
    
    func overlaps(with other: TimeRange) -> Bool {
        start < other.end && end > other.start
    }
}
```

### Entities

```swift
// Domain/AudioGeneration/Entities/Voice.swift
struct Voice: Equatable, Identifiable {
    let id: String
    let name: String
    let language: String
    let provider: TTSProvider
    let isDefault: Bool
    
    enum TTSProvider: String, Equatable {
        case native     // AVSpeechSynthesizer
        case kokoro     // Kokoro TTS (local)
        case qwen3      // Qwen3-TTS (local o API)
    }
}
```

### Aggregates

```swift
// Domain/ProjectManagement/Entities/Project.swift (Aggregate Root)
final class Project {
    private(set) var id: ProjectId
    private(set) var name: ProjectName
    private(set) var text: Text
    private(set) var voice: VoiceConfiguration
    private(set) var provider: Voice.TTSProvider
    private(set) var audioPath: String?
    private(set) var segments: [AudioSegment]
    private(set) var createdAt: Date
    private(set) var updatedAt: Date
    private(set) var status: ProjectStatus
    
    // Domain Events
    private(set) var domainEvents: [DomainEvent] = []
    
    init(name: ProjectName, text: Text, voice: VoiceConfiguration, provider: Voice.TTSProvider) {
        self.id = ProjectId()
        self.name = name
        self.text = text
        self.voice = voice
        self.provider = provider
        self.segments = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = .draft
        
        addEvent(ProjectCreated(projectId: id, name: name, createdAt: createdAt))
    }
    
    // Reconstitución desde persistencia
    init(id: ProjectId, name: ProjectName, text: Text, voice: VoiceConfiguration, 
         provider: Voice.TTSProvider, audioPath: String?, segments: [AudioSegment],
         createdAt: Date, updatedAt: Date, status: ProjectStatus) {
        self.id = id
        self.name = name
        self.text = text
        self.voice = voice
        self.provider = provider
        self.audioPath = audioPath
        self.segments = segments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
    }
    
    // MARK: - Comportamiento del Dominio
    
    func updateText(_ newText: Text) {
        self.text = newText
        self.audioPath = nil  // Invalidar audio existente
        self.status = .draft
        touch()
    }
    
    func rename(_ newName: ProjectName) {
        self.name = newName
        touch()
    }
    
    func markAudioGenerated(path: String, duration: TimeInterval) {
        self.audioPath = path
        self.status = .ready
        touch()
        addEvent(AudioGenerated(projectId: id, audioPath: path, duration: duration))
    }
    
    func addSegment(_ segment: AudioSegment) throws {
        // Validar que no se solape con segmentos existentes
        for existing in segments {
            if segment.timeRange.overlaps(with: existing.timeRange) {
                throw DomainError.segmentsOverlap
            }
        }
        segments.append(segment)
        segments.sort { $0.timeRange.start < $1.timeRange.start }
        touch()
    }
    
    func removeSegment(id: SegmentId) {
        segments.removeAll { $0.id == id }
        touch()
    }
    
    private func touch() {
        updatedAt = Date()
    }
    
    private func addEvent(_ event: DomainEvent) {
        domainEvents.append(event)
    }
    
    func clearEvents() {
        domainEvents.removeAll()
    }
}

enum ProjectStatus: String {
    case draft      // Sin audio generado
    case generating // Generando audio
    case ready      // Audio listo
    case error      // Error en generación
}
```

```swift
// Domain/AudioEditing/Entities/AudioSegment.swift
struct AudioSegment: Equatable, Identifiable {
    let id: SegmentId
    let text: Text
    let timeRange: TimeRange
    let audioPath: String?
    
    init(text: Text, timeRange: TimeRange, audioPath: String? = nil) {
        self.id = SegmentId()
        self.text = text
        self.timeRange = timeRange
        self.audioPath = audioPath
    }
}

## Ports (Interfaces del Dominio)

```swift
// Domain/AudioGeneration/Ports/TTSPort.swift
protocol TTSPort {
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData
    func availableVoices() async -> [Voice]
    var isAvailable: Bool { get }
}

// Domain/ProjectManagement/Ports/ProjectRepositoryPort.swift
protocol ProjectRepositoryPort {
    func save(_ project: Project) async throws
    func findById(_ id: ProjectId) async throws -> Project?
    func findAll() async throws -> [Project]
    func delete(_ id: ProjectId) async throws
    func search(query: String) async throws -> [Project]
}

// Domain/AudioEditing/Ports/AudioEditorPort.swift
protocol AudioEditorPort {
    func trim(audioPath: String, range: TimeRange) async throws -> String
    func merge(audioPaths: [String]) async throws -> String
    func adjustSpeed(audioPath: String, rate: Double) async throws -> String
    func adjustVolume(audioPath: String, factor: Double) async throws -> String
    func fadeIn(audioPath: String, duration: TimeInterval) async throws -> String
    func fadeOut(audioPath: String, duration: TimeInterval) async throws -> String
}

// Domain/Shared/Ports/AudioStoragePort.swift
protocol AudioStoragePort {
    func save(audio: AudioData, projectId: ProjectId) async throws -> String
    func load(path: String) async throws -> AudioData
    func delete(path: String) async throws
    func export(path: String, format: AudioFormat, quality: AudioQuality) async throws -> Data
}

// Domain/DocumentProcessing/Ports/OCRPort.swift
protocol OCRPort {
    func recognizeText(from imagePath: String) async throws -> RecognizedText
    func recognizeText(from imageData: Data) async throws -> RecognizedText
    var isAvailable: Bool { get }
}

// Domain/DocumentProcessing/Ports/DocumentParserPort.swift
protocol DocumentParserPort {
    func extractPages(from pdfPath: String) async throws -> [PageImage]
    func extractPages(from epubPath: String) async throws -> [PageImage]
    func pageCount(in documentPath: String) async throws -> Int
}

// Domain/DocumentProcessing/Ports/ScreenshotPort.swift
protocol ScreenshotPort {
    func captureInteractive() async throws -> CapturedImage
    func captureRegion(_ region: CGRect) async throws -> CapturedImage
}

// Domain/Translation/Ports/TranslationPort.swift
protocol TranslationPort {
    func translate(text: TranslationText, from source: Language, to target: Language) async throws -> TranslatedText
    func detectLanguage(text: String) async throws -> Language
    var isAvailable: Bool { get }
}

// Domain/ClipboardAndHotkeys/Ports/ClipboardPort.swift
protocol ClipboardPort {
    func readText() async throws -> String
    func writeText(_ text: String) async throws
    func copySelection() async throws
}

// Domain/ClipboardAndHotkeys/Ports/HotkeyPort.swift
protocol HotkeyPort {
    func register(hotkey: Hotkey, handler: @escaping () -> Void) async throws
    func unregister(hotkey: Hotkey) async throws
    func unregisterAll() async throws
}
```

## Use Cases (Application Layer)

```swift
// Application/UseCases/GenerateAudio/GenerateAudioUseCase.swift
final class GenerateAudioUseCase {
    private let ttsPort: TTSPort
    private let storagePort: AudioStoragePort
    private let projectRepository: ProjectRepositoryPort
    
    init(ttsPort: TTSPort, storagePort: AudioStoragePort, projectRepository: ProjectRepositoryPort) {
        self.ttsPort = ttsPort
        self.storagePort = storagePort
        self.projectRepository = projectRepository
    }
    
    func execute(_ request: GenerateAudioRequest) async throws -> GenerateAudioResponse {
        // 1. Recuperar proyecto
        guard let project = try await projectRepository.findById(request.projectId) else {
            throw ApplicationError.projectNotFound
        }
        
        // 2. Generar audio via TTS
        let audioData = try await ttsPort.synthesize(
            text: project.text,
            voice: project.voice
        )
        
        // 3. Guardar audio
        let audioPath = try await storagePort.save(audio: audioData, projectId: project.id)
        
        // 4. Actualizar proyecto (comportamiento del dominio)
        project.markAudioGenerated(path: audioPath, duration: audioData.duration)
        
        // 5. Persistir cambios
        try await projectRepository.save(project)
        
        // 6. Retornar respuesta
        return GenerateAudioResponse(
            projectId: project.id,
            audioPath: audioPath,
            duration: audioData.duration
        )
    }
}

struct GenerateAudioRequest {
    let projectId: ProjectId
}

struct GenerateAudioResponse {
    let projectId: ProjectId
    let audioPath: String
    let duration: TimeInterval
}
```

```swift
// Application/UseCases/ManageProjects/CreateProjectUseCase.swift
final class CreateProjectUseCase {
    private let projectRepository: ProjectRepositoryPort
    
    init(projectRepository: ProjectRepositoryPort) {
        self.projectRepository = projectRepository
    }
    
    func execute(_ request: CreateProjectRequest) async throws -> CreateProjectResponse {
        // 1. Crear Value Objects (validación en construcción)
        let text = try Text(request.text)
        let name = try ProjectName(request.name ?? ProjectName.fromText(text).value)
        let speed = try VoiceConfiguration.Speed(request.speed ?? 1.0)
        let pitch = try VoiceConfiguration.Pitch(request.pitch ?? 1.0)
        
        let voiceConfig = VoiceConfiguration(
            voiceId: request.voiceId,
            speed: speed,
            pitch: pitch
        )
        
        // 2. Crear Aggregate (Project)
        let project = Project(
            name: name,
            text: text,
            voice: voiceConfig,
            provider: request.provider
        )
        
        // 3. Persistir
        try await projectRepository.save(project)
        
        // 4. Retornar DTO
        return CreateProjectResponse(
            projectId: project.id,
            name: project.name.value,
            createdAt: project.createdAt
        )
    }
}
```

## TDD - Test-Driven Development

### Ciclo Red-Green-Refactor

1. **RED** - Escribir un test que falle
2. **GREEN** - Escribir el código mínimo para que pase
3. **REFACTOR** - Mejorar el código manteniendo los tests en verde

### Estructura de Tests

```swift
// Tests/Domain/ProjectManagement/ProjectTests.swift
final class ProjectTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func test_createProject_withValidData_shouldSucceed() throws {
        // Arrange
        let name = try ProjectName("Mi Proyecto")
        let text = try Text("Hola mundo")
        let voice = VoiceConfiguration(
            voiceId: "default",
            speed: .normal,
            pitch: .normal
        )
        
        // Act
        let project = Project(name: name, text: text, voice: voice, provider: .native)
        
        // Assert
        XCTAssertEqual(project.name, name)
        XCTAssertEqual(project.text, text)
        XCTAssertEqual(project.status, .draft)
        XCTAssertTrue(project.domainEvents.contains { $0 is ProjectCreated })
    }
    
    func test_createProject_shouldGenerateUniqueId() throws {
        // Arrange
        let name = try ProjectName("Test")
        let text = try Text("Texto")
        let voice = VoiceConfiguration(voiceId: "v1", speed: .normal, pitch: .normal)
        
        // Act
        let project1 = Project(name: name, text: text, voice: voice, provider: .native)
        let project2 = Project(name: name, text: text, voice: voice, provider: .native)
        
        // Assert
        XCTAssertNotEqual(project1.id, project2.id)
    }
    
    // MARK: - Behavior Tests
    
    func test_updateText_shouldInvalidateAudio() throws {
        // Arrange
        var project = try makeProjectWithAudio()
        XCTAssertNotNil(project.audioPath)
        
        // Act
        let newText = try Text("Nuevo texto")
        project.updateText(newText)
        
        // Assert
        XCTAssertNil(project.audioPath)
        XCTAssertEqual(project.status, .draft)
    }
    
    func test_markAudioGenerated_shouldEmitEvent() throws {
        // Arrange
        let project = try makeProject()
        project.clearEvents()
        
        // Act
        project.markAudioGenerated(path: "/audio/test.m4a", duration: 10.5)
        
        // Assert
        XCTAssertEqual(project.status, .ready)
        XCTAssertTrue(project.domainEvents.contains { $0 is AudioGenerated })
    }
    
    // MARK: - Helpers
    
    private func makeProject() throws -> Project {
        Project(
            name: try ProjectName("Test"),
            text: try Text("Texto de prueba"),
            voice: VoiceConfiguration(voiceId: "v1", speed: .normal, pitch: .normal),
            provider: .native
        )
    }
    
    private func makeProjectWithAudio() throws -> Project {
        let project = try makeProject()
        project.markAudioGenerated(path: "/audio/test.m4a", duration: 5.0)
        return project
    }
}
```

```swift
// Tests/Domain/AudioGeneration/TextValueObjectTests.swift
final class TextValueObjectTests: XCTestCase {
    
    func test_createText_withValidString_shouldSucceed() throws {
        // Act
        let text = try Text("Hola mundo")
        
        // Assert
        XCTAssertEqual(text.value, "Hola mundo")
    }
    
    func test_createText_withEmptyString_shouldThrow() {
        // Act & Assert
        XCTAssertThrowsError(try Text("")) { error in
            guard case DomainError.invalidText = error else {
                XCTFail("Expected invalidText error")
                return
            }
        }
    }
    
    func test_createText_withWhitespaceOnly_shouldThrow() {
        XCTAssertThrowsError(try Text("   \n\t  "))
    }
    
    func test_createText_exceedingLimit_shouldThrow() {
        let longText = String(repeating: "a", count: 10001)
        XCTAssertThrowsError(try Text(longText))
    }
    
    func test_wordCount_shouldCalculateCorrectly() throws {
        let text = try Text("Uno dos tres cuatro cinco")
        XCTAssertEqual(text.wordCount, 5)
    }
    
    func test_estimatedDuration_shouldCalculate() throws {
        let text = try Text(String(repeating: "palabra ", count: 150))
        // 150 palabras / 150 wpm = 1 minuto = 60 segundos
        XCTAssertEqual(text.estimatedDuration, 60, accuracy: 1)
    }
}
```

```swift
// Tests/Application/GenerateAudioUseCaseTests.swift
final class GenerateAudioUseCaseTests: XCTestCase {
    
    var sut: GenerateAudioUseCase!
    var mockTTS: MockTTSPort!
    var mockStorage: MockAudioStoragePort!
    var mockRepository: MockProjectRepositoryPort!
    
    override func setUp() {
        mockTTS = MockTTSPort()
        mockStorage = MockAudioStoragePort()
        mockRepository = MockProjectRepositoryPort()
        
        sut = GenerateAudioUseCase(
            ttsPort: mockTTS,
            storagePort: mockStorage,
            projectRepository: mockRepository
        )
    }
    
    func test_execute_withValidProject_shouldGenerateAudio() async throws {
        // Arrange
        let project = try TestFixtures.makeProject()
        mockRepository.projectToReturn = project
        mockTTS.audioDataToReturn = AudioData(data: Data(), duration: 10.0)
        mockStorage.pathToReturn = "/audio/\(project.id.value).m4a"
        
        let request = GenerateAudioRequest(projectId: project.id)
        
        // Act
        let response = try await sut.execute(request)
        
        // Assert
        XCTAssertEqual(response.projectId, project.id)
        XCTAssertEqual(response.duration, 10.0)
        XCTAssertTrue(mockTTS.synthesizeCalled)
        XCTAssertTrue(mockStorage.saveCalled)
        XCTAssertTrue(mockRepository.saveCalled)
    }
    
    func test_execute_withNonexistentProject_shouldThrow() async {
        // Arrange
        mockRepository.projectToReturn = nil
        let request = GenerateAudioRequest(projectId: ProjectId())
        
        // Act & Assert
        do {
            _ = try await sut.execute(request)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is ApplicationError)
        }
    }
    
    func test_execute_whenTTSFails_shouldPropagateError() async {
        // Arrange
        let project = try! TestFixtures.makeProject()
        mockRepository.projectToReturn = project
        mockTTS.errorToThrow = TTSError.synthesizeFailed
        
        // Act & Assert
        do {
            _ = try await sut.execute(GenerateAudioRequest(projectId: project.id))
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is TTSError)
        }
    }
}
```

```swift
// Tests/Mocks/MockTTSPort.swift
final class MockTTSPort: TTSPort {
    var synthesizeCalled = false
    var lastText: Text?
    var lastVoice: VoiceConfiguration?
    var audioDataToReturn: AudioData?
    var errorToThrow: Error?
    
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData {
        synthesizeCalled = true
        lastText = text
        lastVoice = voice
        
        if let error = errorToThrow {
            throw error
        }
        
        return audioDataToReturn ?? AudioData(data: Data(), duration: 0)
    }
    
    var voicesToReturn: [Voice] = []
    func availableVoices() async -> [Voice] {
        voicesToReturn
    }
    
    var isAvailable: Bool = true
}
```

## Convenciones de Código

### Naming
- **Domain Entities:** PascalCase (`Project`, `Voice`, `AudioSegment`)
- **Value Objects:** PascalCase (`Text`, `ProjectName`, `TimeRange`)
- **Ports (Interfaces):** Sufijo `Port` (`TTSPort`, `ProjectRepositoryPort`)
- **Adapters:** Sufijo `Adapter` (`NativeTTSAdapter`, `SwiftDataProjectRepository`)
- **Use Cases:** Sufijo `UseCase` (`CreateProjectUseCase`, `GenerateAudioUseCase`)
- **Tests:** Sufijo `Tests` (`ProjectTests`, `GenerateAudioUseCaseTests`)

### Domain Layer Rules
- **NO imports de frameworks externos** (excepto Foundation cuando sea inevitable)
- Value Objects son **inmutables** (struct con let)
- Entities tienen **identidad** (id único)
- Aggregates protegen sus **invariantes**
- La lógica de negocio vive en el **dominio**, no en Use Cases

### Test Naming Convention
```
func test_[método]_[condición]_[resultado]()

// Ejemplos:
func test_createProject_withEmptyName_shouldThrow()
func test_updateText_whenProjectHasAudio_shouldInvalidateAudio()
func test_execute_withValidRequest_shouldReturnResponse()
```

### Arrange-Act-Assert (AAA)
```swift
func test_example() {
    // Arrange - Preparar datos y mocks
    let input = "test"
    
    // Act - Ejecutar la acción
    let result = sut.process(input)
    
    // Assert - Verificar resultados
    XCTAssertEqual(result, expected)
}
```

### SwiftUI Views (UI Layer)
- Un archivo por vista
- Views son "tontas" - sin lógica de negocio
- Presenters coordinan con Use Cases
- ViewModels solo contienen estado de UI

## Comandos Útiles

### Build
```bash
xcodebuild -scheme TextToAudio -configuration Debug build
```

### Test
```bash
xcodebuild -scheme TextToAudio -configuration Debug test
```

### Archive para App Store
```bash
xcodebuild -scheme TextToAudio -configuration Release archive
```

## Requisitos para App Store

### Obligatorios
- [ ] App Sandbox habilitado
- [ ] Signing con certificado de distribución
- [ ] Icono de app en todos los tamaños requeridos
- [ ] Privacy descriptions en Info.plist
- [ ] Versión mínima: macOS 14.0 (para SwiftData)

### Info.plist Keys Necesarias
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Para grabar audio personalizado</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Para transcripción de audio</string>
```

### Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

## Flujos Principales

### 1. Crear nuevo proyecto
1. Usuario escribe o pega texto
2. Selecciona voz y proveedor
3. Click en "Generar Audio"
4. Sistema procesa y guarda
5. Muestra reproductor con waveform

### 2. Editar audio existente
1. Usuario selecciona proyecto
2. Puede editar texto (regenera segmento)
3. Puede cortar/unir segmentos
4. Puede ajustar velocidad/tono
5. Guarda cambios

### 3. Exportar
1. Usuario selecciona formato (MP3, WAV, M4A)
2. Selecciona calidad
3. Elige ubicación
4. Sistema exporta

## Dependencias Externas

### Swift Package Manager
```swift
dependencies: [
    // Para waveform visualization
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage", from: "14.0.0"),
    // Para networking (opcional, URLSession es suficiente)
    // .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
]
```

## Variables de Entorno / Configuración

Crear archivo `Secrets.swift` (añadir a .gitignore):
```swift
enum Secrets {
    static let openAIAPIKey = "sk-..."
    static let elevenLabsAPIKey = "..."
}
```

Para producción, usar Keychain o CloudKit para almacenar API keys del usuario.

## Testing

### Unit Tests
- Testear ViewModels con mocks de servicios
- Testear Services con datos de prueba
- Testear conversión de formatos

### UI Tests
- Flujo completo de creación de proyecto
- Reproducción de audio
- Exportación

## Notas Adicionales

### Performance
- Usar `@MainActor` para updates de UI
- Procesar audio en background threads
- Implementar caché para audios generados

### Accesibilidad
- VoiceOver support en todas las vistas
- Keyboard navigation
- Dynamic Type support

### Localización
- Preparar strings para localización
- Soportar al menos: Español, Inglés
