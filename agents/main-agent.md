# Agente: Principal / Orquestador

## Rol
Agente principal que coordina el desarrollo del proyecto ReaderPro usando DDD, Arquitectura Hexagonal y TDD.

## Ubicación
`agents/main-agent.md`

## Agentes Relacionados
- `agents/architecture-agent.md` - DDD, Hexagonal, TDD
- `agents/audio-agent.md` - Kokoro, Qwen3, AVFoundation
- `agents/infrastructure-agent.md` - SwiftData, FileSystem
- `agents/ui-agent.md` - SwiftUI, Presenters

## Metodología de Desarrollo

### TDD - Test-Driven Development
```
1. 🔴 RED    → Escribir test que falla
2. 🟢 GREEN  → Escribir código mínimo para pasar
3. 🔵 REFACTOR → Mejorar sin romper tests
```

### Arquitectura Hexagonal
```
UI → Application → Domain ← Infrastructure
```

## Fases del Proyecto (TDD)

### Fase 1: Domain Foundation (Semana 1-2)

#### 1.1 Value Objects (test → impl → refactor)
1. Identifier<T>
2. Text
3. ProjectName
4. VoiceConfiguration
5. TimeRange
6. AudioData
7. ProjectStatus

#### 1.2 Entities
1. Voice
2. AudioSegment
3. Project (Aggregate Root)

#### 1.3 Ports (Interfaces)
1. TTSPort
2. ProjectRepositoryPort
3. AudioEditorPort
4. AudioStoragePort

### Fase 2: Application Layer (Semana 3-4)

#### Use Cases + Tests
- CreateProjectUseCase
- GetProjectUseCase
- ListProjectsUseCase
- GenerateAudioUseCase
- TrimAudioUseCase
- ExportAudioUseCase

### Fase 3: Infrastructure (Semana 5-6)

#### Adapters
- SwiftDataProjectRepository
- NativeTTSAdapter (AVSpeechSynthesizer)
- KokoroTTSAdapter (servidor local)
- Qwen3TTSAdapter (Ollama/local)
- AVFoundationEditorAdapter

### Fase 4: UI Layer (Semana 7-8)

#### Presenters + Views
- ProjectListPresenter/View
- EditorPresenter/View
- PlayerPresenter/View

### Fase 5-6: Polish & App Store (Semana 9-12)

## Comandos para Claude Code

```bash
# Inicio de sesión - Analizar script existente
> Lee CLAUDE.md y analiza mac_reader_pro_V1.8.2.py.
> Dame un resumen de funcionalidades a migrar.

# Inicio de sesión - Implementar con TDD
> Lee CLAUDE.md y agents/architecture-agent.md. Vamos a implementar [X] con TDD.

# Value Object
> Implementa 'TimeRange' con TDD: tests primero, luego implementación.

# Use Case
> Implementa CreateProjectUseCase con TDD y mocks de Ports.

# Adapter de TTS
> Lee agents/audio-agent.md e implementa KokoroTTSAdapter.

# Verificar arquitectura
> Revisa que Domain/ no tenga imports externos.
```

## Reglas TDD

1. **No código sin test** - Test primero, siempre
2. **Test mínimo** - Un test a la vez
3. **Arrange-Act-Assert** - Estructura clara
4. **Nombres descriptivos** - `test_método_condición_resultado`

## Métricas de Calidad

| Capa | Cobertura Mínima |
|------|------------------|
| Domain | 90% |
| Application | 85% |
| Infrastructure | 60% |
| UI | 40% |

## Reglas de Arquitectura

- [ ] Domain: 0 imports de frameworks externos
- [ ] Application: 0 imports de Infrastructure
- [ ] Ports: Solo tipos del dominio
- [ ] Tests primero para cada feature

## Checklist Pre-Implementación

- [ ] ¿He identificado los Value Objects?
- [ ] ¿Cuál es el Aggregate Root?
- [ ] ¿Qué Ports necesito?
- [ ] ¿He escrito los tests primero?
