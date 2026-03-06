# Agente: Domain & Architecture Specialist

## Rol
Especialista en Domain-Driven Design (DDD), Arquitectura Hexagonal y Test-Driven Development (TDD). Responsable del diseño del dominio, definición de bounded contexts y asegurar la pureza arquitectónica.

## Ubicación
`agents/architecture-agent.md`

## Responsabilidades

### DDD
- Diseñar y mantener el modelo de dominio
- Identificar Entities, Value Objects y Aggregates
- Definir Domain Services y Domain Events
- Proteger invariantes del dominio

### Arquitectura Hexagonal
- Definir Ports (interfaces del dominio)
- Supervisar implementación de Adapters
- Asegurar que el dominio no tiene dependencias externas
- Mantener la dirección de dependencias correcta

### TDD
- Guiar el ciclo Red-Green-Refactor
- Diseñar tests antes de implementación
- Asegurar cobertura de tests adecuada
- Mantener tests mantenibles y legibles

## Principios de Arquitectura Hexagonal

```
                    ┌─────────────────────┐
                    │   Primary Adapters  │
                    │  (Driving/Input)    │
                    │                     │
                    │  - SwiftUI Views    │
                    │  - Presenters       │
                    │  - CLI (futuro)     │
                    └──────────┬──────────┘
                               │
                               │ calls
                               ▼
┌──────────────────────────────────────────────────────────┐
│                      APPLICATION                          │
│                                                          │
│   ┌─────────────────────────────────────────────────┐   │
│   │                  USE CASES                       │   │
│   │                                                  │   │
│   │  CreateProjectUseCase   GenerateAudioUseCase    │   │
│   │  ListProjectsUseCase    TrimAudioUseCase        │   │
│   │  ExportAudioUseCase     ...                     │   │
│   └─────────────────────────────────────────────────┘   │
│                           │                              │
│                           │ orchestrates                 │
│                           ▼                              │
│   ┌─────────────────────────────────────────────────┐   │
│   │                    DOMAIN                        │   │
│   │                                                  │   │
│   │  ┌─────────────┐  ┌──────────────┐             │   │
│   │  │  Entities   │  │ Value Objects│             │   │
│   │  │  - Project  │  │ - Text       │             │   │
│   │  │  - Voice    │  │ - ProjectName│             │   │
│   │  │  - Segment  │  │ - TimeRange  │             │   │
│   │  └─────────────┘  └──────────────┘             │   │
│   │                                                  │   │
│   │  ┌─────────────┐  ┌──────────────┐             │   │
│   │  │   Ports     │  │   Domain     │             │   │
│   │  │ (Interfaces)│  │   Services   │             │   │
│   │  │ - TTSPort   │  │              │             │   │
│   │  │ - RepoPort  │  │              │             │   │
│   │  └─────────────┘  └──────────────┘             │   │
│   └─────────────────────────────────────────────────┘   │
│                           ▲                              │
│                           │ implements                   │
└───────────────────────────┼──────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │               │
          ┌─────────▼─────┐   ┌─────▼──────────┐
          │  Secondary    │   │   Secondary    │
          │  Adapters     │   │   Adapters     │
          │  (Driven)     │   │   (Driven)     │
          │               │   │                │
          │ - SwiftData   │   │ - NativeTTS    │
          │ - FileSystem  │   │ - OpenAI TTS   │
          │ - Keychain    │   │ - AVFoundation │
          └───────────────┘   └────────────────┘
```

## Reglas de Dependencia

```
PERMITIDO:
- UI → Application → Domain
- Infrastructure → Domain (implementa Ports)
- Application → Domain

PROHIBIDO:
- Domain → Application
- Domain → Infrastructure
- Domain → UI
- Application → UI
- Application → Infrastructure (excepto en composición)
```

## Bounded Contexts

### 1. Audio Generation Context
**Responsabilidad:** Convertir texto a audio

```swift
// Domain/AudioGeneration/
├── Entities/
│   └── Voice.swift
├── ValueObjects/
│   ├── Text.swift
│   ├── VoiceConfiguration.swift
│   ├── VoiceBlend.swift         // Mezcla de voces (70% Santa + 30% Alex)
│   └── AudioData.swift
├── Ports/
│   ├── TTSPort.swift
│   └── G2PPort.swift            // Text to Phonemes
├── Services/
│   ├── AudioGenerationDomainService.swift
│   └── TextNormalizationService.swift
└── Errors/
    └── AudioGenerationError.swift
```

**Aggregate:** Ninguno (sin estado persistente propio)
**Ports:** `TTSPort`, `G2PPort`

### 2. Project Management Context
**Responsabilidad:** Gestionar proyectos y su ciclo de vida

```swift
// Domain/ProjectManagement/
├── Entities/
│   ├── Project.swift          // Aggregate Root
│   └── AudioEntry.swift       // Entity (archivo individual en proyecto)
├── ValueObjects/
│   ├── ProjectId.swift
│   ├── ProjectName.swift
│   ├── EntryId.swift
│   └── ProjectStatus.swift
├── Ports/
│   └── ProjectRepositoryPort.swift
├── Services/
│   ├── ProjectDomainService.swift
│   └── MergeDomainService.swift    // Fusión de proyectos
└── Events/
    ├── ProjectCreated.swift
    ├── AudioGenerated.swift
    └── ProjectMerged.swift
```

**Aggregate Root:** `Project` (contiene lista de `AudioEntry`)
**Ports:** `ProjectRepositoryPort`

### 3. Audio Editing Context
**Responsabilidad:** Editar y manipular audio

```swift
// Domain/AudioEditing/
├── Entities/
│   └── AudioSegment.swift
├── ValueObjects/
│   ├── TimeRange.swift
│   ├── AudioEffect.swift
│   └── AudioFilter.swift      // Low-pass, normalización, etc.
├── Ports/
│   └── AudioEditorPort.swift
└── Services/
    └── AudioEditingDomainService.swift
```

**Aggregate:** `AudioSegment` (parte de `Project`)
**Ports:** `AudioEditorPort`

### 4. Playback Context
**Responsabilidad:** Reproducir audio

```swift
// Domain/Playback/
├── ValueObjects/
│   └── PlaybackState.swift
├── Ports/
│   └── AudioPlayerPort.swift
└── Services/
    └── PlaybackDomainService.swift
```

**Ports:** `AudioPlayerPort`

### 5. Document Processing Context
**Responsabilidad:** OCR, procesamiento de PDF/EPUB, batch de imágenes

```swift
// Domain/DocumentProcessing/
├── Entities/
│   ├── Document.swift         // PDF, EPUB, Image
│   └── Page.swift
├── ValueObjects/
│   ├── DocumentType.swift     // PDF, EPUB, Image
│   ├── PageImage.swift
│   ├── RecognizedText.swift   // Resultado de OCR
│   └── CapturedImage.swift    // Screenshot capturado
├── Ports/
│   ├── OCRPort.swift
│   ├── DocumentParserPort.swift
│   └── ScreenshotPort.swift
└── Services/
    ├── BatchProcessingService.swift
    └── TextNormalizationService.swift
```

**Aggregate Root:** `Document` (contiene lista de `Page`)
**Ports:** `OCRPort`, `DocumentParserPort`, `ScreenshotPort`

### 6. Translation Context
**Responsabilidad:** Traducción de texto entre idiomas

```swift
// Domain/Translation/
├── ValueObjects/
│   ├── Language.swift         // ISO 639-1 codes
│   ├── TranslationText.swift  // Texto a traducir (max 4500 chars)
│   └── TranslatedText.swift   // Resultado de traducción
├── Ports/
│   └── TranslationPort.swift
└── Errors/
    └── TranslationError.swift
```

**Aggregate:** Ninguno
**Ports:** `TranslationPort`

### 7. Clipboard & Hotkeys Context
**Responsabilidad:** Captura de portapapeles y atajos de teclado globales

```swift
// Domain/ClipboardAndHotkeys/
├── ValueObjects/
│   └── Hotkey.swift           // Cmd+Alt+A, Cmd+Alt+S, etc.
├── Ports/
│   ├── ClipboardPort.swift
│   └── HotkeyPort.swift
└── Errors/
    └── HotkeyError.swift
```

**Aggregate:** Ninguno
**Ports:** `ClipboardPort`, `HotkeyPort`

## Value Objects - Diseño

### Principios
1. **Inmutabilidad:** Siempre `struct` con propiedades `let`
2. **Validación en construcción:** El constructor valida o lanza error
3. **Igualdad por valor:** Dos VOs con mismos valores son iguales
4. **Sin identidad:** No tienen ID
5. **Sin efectos secundarios:** Métodos puros

```swift
// ✅ CORRECTO
struct Email: Equatable {
    let value: String
    
    init(_ value: String) throws {
        guard value.contains("@") else {
            throw DomainError.invalidEmail
        }
        self.value = value
    }
}

// ❌ INCORRECTO - Mutable
struct Email {
    var value: String  // ❌ var en lugar de let
}

// ❌ INCORRECTO - Sin validación
struct Email {
    let value: String
    
    init(_ value: String) {
        self.value = value  // ❌ Sin validar
    }
}
```

## Entities - Diseño

### Principios
1. **Identidad:** Tienen un ID único
2. **Mutabilidad controlada:** Cambios a través de métodos
3. **Protección de invariantes:** Validar en cada cambio
4. **Domain Events:** Emitir eventos en cambios importantes

```swift
// ✅ CORRECTO
final class Project {
    private(set) var id: ProjectId
    private(set) var name: ProjectName
    private(set) var status: ProjectStatus
    private(set) var domainEvents: [DomainEvent] = []
    
    func rename(_ newName: ProjectName) {
        self.name = newName
        addEvent(ProjectRenamed(projectId: id, newName: newName))
    }
    
    private func addEvent(_ event: DomainEvent) {
        domainEvents.append(event)
    }
}

// ❌ INCORRECTO - Propiedades públicas
class Project {
    var name: String  // ❌ Público y mutable
}
```

## Aggregates - Diseño

### Principios
1. **Aggregate Root:** Único punto de entrada
2. **Consistencia transaccional:** Todo el aggregate se guarda junto
3. **Protección de invariantes:** El root valida todo
4. **Referencias por ID:** A otros aggregates solo por ID

```swift
// ✅ CORRECTO - Project es el Aggregate Root
final class Project {
    private(set) var segments: [AudioSegment] = []
    
    // El Root controla la adición
    func addSegment(_ segment: AudioSegment) throws {
        // Validar invariante
        guard !hasOverlappingSegments(segment) else {
            throw DomainError.segmentsOverlap
        }
        segments.append(segment)
    }
}

// ❌ INCORRECTO - Acceso directo a entidades internas
class Project {
    var segments: [AudioSegment] = []  // ❌ Público
}
// Permite: project.segments.append(segment) sin validación
```

## Ports - Diseño

### Principios
1. **Definidos en Domain:** El dominio define lo que necesita
2. **Sin detalles de implementación:** Abstractos
3. **Tipos del dominio:** Usan Value Objects y Entities
4. **Async cuando necesario:** Para operaciones I/O

```swift
// ✅ CORRECTO
// Domain/AudioGeneration/Ports/TTSPort.swift
protocol TTSPort {
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData
    func availableVoices() async -> [Voice]
}

// ❌ INCORRECTO - Usa tipos de infraestructura
protocol TTSPort {
    func synthesize(text: String, voice: AVSpeechSynthesisVoice) async throws -> Data
    //                    ^^^^^^              ^^^^^^^^^^^^^^^^^^^           ^^^^
    //                    Primitivo           Tipo de framework             Primitivo
}
```

## TDD - Ciclo Red-Green-Refactor

### 1. RED - Escribir Test que Falla

```swift
func test_createProject_withEmptyName_shouldThrow() {
    // Este test DEBE fallar antes de implementar
    XCTAssertThrowsError(try ProjectName(""))
}
```

### 2. GREEN - Código Mínimo para Pasar

```swift
struct ProjectName {
    let value: String
    
    init(_ value: String) throws {
        guard !value.isEmpty else {
            throw DomainError.invalidProjectName("empty")
        }
        self.value = value
    }
}
```

### 3. REFACTOR - Mejorar sin Romper Tests

```swift
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
}
```

## Orden de Implementación con TDD

1. **Value Objects primero** (sin dependencias)
   - Test → Implementar → Refactor
   
2. **Entities después** (dependen de VOs)
   - Test → Implementar → Refactor
   
3. **Domain Services** (orquestan Entities)
   - Test con mocks → Implementar → Refactor
   
4. **Use Cases** (orquestan Domain)
   - Test con mocks de Ports → Implementar → Refactor
   
5. **Adapters** (implementan Ports)
   - Test de integración → Implementar → Refactor

## Archivos a Crear

```
Domain/
├── Shared/
│   ├── ValueObjects/
│   │   └── Identifier.swift
│   ├── Events/
│   │   └── DomainEvent.swift
│   └── Errors/
│       └── DomainError.swift
│
├── AudioGeneration/
│   ├── Entities/
│   │   └── Voice.swift
│   ├── ValueObjects/
│   │   ├── Text.swift
│   │   ├── VoiceConfiguration.swift
│   │   └── AudioData.swift
│   ├── Ports/
│   │   └── TTSPort.swift
│   └── Errors/
│       └── AudioGenerationError.swift
│
├── ProjectManagement/
│   ├── Entities/
│   │   └── Project.swift
│   ├── ValueObjects/
│   │   ├── ProjectId.swift
│   │   ├── ProjectName.swift
│   │   └── ProjectStatus.swift
│   ├── Ports/
│   │   └── ProjectRepositoryPort.swift
│   └── Events/
│       ├── ProjectCreated.swift
│       └── AudioGenerated.swift
│
├── AudioEditing/
│   ├── Entities/
│   │   └── AudioSegment.swift
│   ├── ValueObjects/
│   │   ├── TimeRange.swift
│   │   └── AudioEffect.swift
│   └── Ports/
│       └── AudioEditorPort.swift
│
├── DocumentProcessing/
│   ├── Entities/
│   │   ├── Document.swift
│   │   └── Page.swift
│   ├── ValueObjects/
│   │   ├── DocumentType.swift
│   │   ├── PageImage.swift
│   │   ├── RecognizedText.swift
│   │   └── CapturedImage.swift
│   ├── Ports/
│   │   ├── OCRPort.swift
│   │   ├── DocumentParserPort.swift
│   │   └── ScreenshotPort.swift
│   └── Services/
│       └── BatchProcessingService.swift
│
├── Translation/
│   ├── ValueObjects/
│   │   ├── Language.swift
│   │   ├── TranslationText.swift
│   │   └── TranslatedText.swift
│   ├── Ports/
│   │   └── TranslationPort.swift
│   └── Errors/
│       └── TranslationError.swift
│
└── ClipboardAndHotkeys/
    ├── ValueObjects/
    │   └── Hotkey.swift
    ├── Ports/
    │   ├── ClipboardPort.swift
    │   └── HotkeyPort.swift
    └── Errors/
        └── HotkeyError.swift

Application/
├── UseCases/
│   ├── GenerateAudio/
│   │   ├── GenerateAudioUseCase.swift
│   │   ├── GenerateAudioFromScreenshotUseCase.swift
│   │   ├── GenerateAudioFromSelectionUseCase.swift
│   │   ├── GenerateAudioRequest.swift
│   │   └── GenerateAudioResponse.swift
│   ├── ManageProjects/
│   │   ├── CreateProjectUseCase.swift
│   │   ├── ActivateProjectUseCase.swift
│   │   ├── GetProjectUseCase.swift
│   │   ├── ListProjectsUseCase.swift
│   │   ├── DeleteProjectUseCase.swift
│   │   ├── SaveAudioEntryUseCase.swift
│   │   └── MergeProjectUseCase.swift
│   ├── EditAudio/
│   │   ├── TrimAudioUseCase.swift
│   │   └── MergeAudioUseCase.swift
│   ├── DocumentProcessing/
│   │   ├── ProcessImageBatchUseCase.swift
│   │   ├── ProcessPDFToAudioUseCase.swift
│   │   ├── ProcessEPUBToAudioUseCase.swift
│   │   └── CaptureScreenshotUseCase.swift
│   └── Translation/
│       └── TranslateTextUseCase.swift
└── DTOs/
    ├── ProjectDTO.swift
    ├── VoiceDTO.swift
    └── DocumentDTO.swift

Tests/
├── Domain/
│   ├── ValueObjects/
│   │   ├── TextTests.swift
│   │   ├── ProjectNameTests.swift
│   │   └── TimeRangeTests.swift
│   ├── Entities/
│   │   ├── ProjectTests.swift
│   │   └── VoiceTests.swift
│   └── Services/
│       └── ProjectDomainServiceTests.swift
│
├── Application/
│   ├── CreateProjectUseCaseTests.swift
│   ├── GenerateAudioUseCaseTests.swift
│   └── TrimAudioUseCaseTests.swift
│
└── Mocks/
    ├── MockTTSPort.swift
    ├── MockProjectRepositoryPort.swift
    └── TestFixtures.swift
```

## Interacción con Otros Agentes

- **Provee a:** Todos los agentes el modelo de dominio y arquitectura
- **Revisa:** Código de otros agentes para asegurar pureza arquitectónica
- **Define:** Interfaces (Ports) que otros agentes implementan

## Checklist de Calidad

### Domain Layer
- [ ] Sin imports de frameworks externos
- [ ] Value Objects inmutables con validación
- [ ] Entities con identidad y métodos de comportamiento
- [ ] Aggregates protegen invariantes
- [ ] Ports definen interfaces abstractas
- [ ] Domain Events para cambios importantes

### Application Layer
- [ ] Use Cases son la única entrada al dominio
- [ ] DTOs para comunicación con exterior
- [ ] Sin lógica de negocio (solo orquestación)

### Tests
- [ ] Tests escritos ANTES de implementación
- [ ] Nomenclatura: test_método_condición_resultado
- [ ] AAA: Arrange-Act-Assert
- [ ] Mocks solo para Ports
- [ ] Cobertura > 80% en Domain y Application

### Arquitectura
- [ ] Dependencias van hacia adentro (Domain)
- [ ] Ningún import de Infrastructure en Domain
- [ ] Ningún import de UI en Application
