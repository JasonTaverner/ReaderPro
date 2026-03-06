# Agente: Infrastructure Specialist

## Rol
Especialista en implementación de Adapters para la capa de infraestructura. Implementa los Ports definidos en el dominio usando frameworks y tecnologías externas.

## Ubicación
`agents/infrastructure-agent.md`

## Responsabilidades

### Adapters de Persistencia
- Implementar `ProjectRepositoryPort` con SwiftData
- Implementar `AudioStoragePort` con FileSystem
- Gestionar Keychain para API keys

### Adapters de TTS
- Implementar `TTSPort` con AVSpeechSynthesizer (nativo)
- Implementar `TTSPort` con Kokoro (local)
- Implementar `TTSPort` con Qwen3-TTS (local/API)

### Adapters de Audio
- Implementar `AudioEditorPort` con AVFoundation
- Implementar `AudioPlayerPort` con AVAudioPlayer
- Waveform generation

## Principio Fundamental

> **Los Adapters implementan Ports del dominio. El dominio NO conoce los adapters.**

```swift
// ✅ CORRECTO - Adapter importa Domain
// Infrastructure/Adapters/Persistence/SwiftDataProjectRepository.swift
import SwiftData
import Domain  // Importa el Port

final class SwiftDataProjectRepository: ProjectRepositoryPort {
    // Implementación...
}

// ❌ INCORRECTO - Domain importa Infrastructure
// Domain/ProjectManagement/Ports/ProjectRepositoryPort.swift
import SwiftData  // ❌ NUNCA
```

## Adapters de Persistencia

### SwiftDataProjectRepository

```swift
// Infrastructure/Adapters/Persistence/SwiftData/SwiftDataProjectRepository.swift
import SwiftData

final class SwiftDataProjectRepository: ProjectRepositoryPort {
    private let modelContainer: ModelContainer
    private let mapper: ProjectMapper
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.mapper = ProjectMapper()
    }
    
    @MainActor
    func save(_ project: Project) async throws {
        let model = mapper.toModel(project)
        let context = modelContainer.mainContext
        context.insert(model)
        try context.save()
    }
    
    @MainActor
    func findById(_ id: ProjectId) async throws -> Project? {
        let context = modelContainer.mainContext
        let uuid = id.value
        let descriptor = FetchDescriptor<ProjectModel>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }
        return mapper.toDomain(model)
    }
    
    @MainActor
    func findAll() async throws -> [Project] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ProjectModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { mapper.toDomain($0) }
    }
    
    @MainActor
    func delete(_ id: ProjectId) async throws {
        let context = modelContainer.mainContext
        let uuid = id.value
        let descriptor = FetchDescriptor<ProjectModel>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let model = try context.fetch(descriptor).first else {
            return
        }
        context.delete(model)
        try context.save()
    }
    
    @MainActor
    func search(query: String) async throws -> [Project] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ProjectModel>(
            predicate: #Predicate { project in
                project.name.localizedStandardContains(query)
            }
        )
        let models = try context.fetch(descriptor)
        return models.map { mapper.toDomain($0) }
    }
}
```

### ProjectModel (SwiftData)

```swift
// Infrastructure/Adapters/Persistence/SwiftData/Models/ProjectModel.swift
import SwiftData

@Model
final class ProjectModel {
    var id: UUID
    var name: String
    var text: String
    var voiceId: String
    var voiceSpeed: Double
    var voicePitch: Double
    var provider: String
    var audioPath: String?
    var status: String
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var segments: [AudioSegmentModel] = []
    
    init(id: UUID, name: String, text: String, voiceId: String,
         voiceSpeed: Double, voicePitch: Double, provider: String,
         audioPath: String?, status: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.text = text
        self.voiceId = voiceId
        self.voiceSpeed = voiceSpeed
        self.voicePitch = voicePitch
        self.provider = provider
        self.audioPath = audioPath
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### ProjectMapper

```swift
// Infrastructure/Adapters/Persistence/SwiftData/Mappers/ProjectMapper.swift

final class ProjectMapper {
    
    func toModel(_ project: Project) -> ProjectModel {
        ProjectModel(
            id: project.id.value,
            name: project.name.value,
            text: project.text.value,
            voiceId: project.voice.voiceId,
            voiceSpeed: project.voice.speed.value,
            voicePitch: project.voice.pitch.value,
            provider: project.provider.rawValue,
            audioPath: project.audioPath,
            status: project.status.rawValue,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
        )
    }
    
    func toDomain(_ model: ProjectModel) -> Project {
        // Reconstruir Value Objects
        let id = ProjectId(model.id)
        let name = try! ProjectName(model.name)
        let text = try! Text(model.text)
        let speed = try! VoiceConfiguration.Speed(model.voiceSpeed)
        let pitch = try! VoiceConfiguration.Pitch(model.voicePitch)
        let voice = VoiceConfiguration(voiceId: model.voiceId, speed: speed, pitch: pitch)
        let provider = Voice.TTSProvider(rawValue: model.provider) ?? .native
        let status = ProjectStatus(rawValue: model.status) ?? .draft
        
        // Reconstruir segmentos
        let segments = model.segments.map { segmentMapper.toDomain($0) }
        
        // Usar constructor de reconstitución
        return Project(
            id: id,
            name: name,
            text: text,
            voice: voice,
            provider: provider,
            audioPath: model.audioPath,
            segments: segments,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            status: status
        )
    }
}
```

### AudioFileStorage

```swift
// Infrastructure/Adapters/Persistence/FileSystem/AudioFileStorage.swift
import Foundation

final class AudioFileStorage: AudioStoragePort {
    private let baseDirectory: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.baseDirectory = appSupport.appendingPathComponent("TextToAudio/Audio", isDirectory: true)
        createDirectoryIfNeeded()
    }
    
    func save(audio: AudioData, projectId: ProjectId) async throws -> String {
        let fileName = "\(projectId.value.uuidString).m4a"
        let url = baseDirectory.appendingPathComponent(fileName)
        try audio.data.write(to: url)
        return fileName
    }
    
    func load(path: String) async throws -> AudioData {
        let url = baseDirectory.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InfrastructureError.fileNotFound(path)
        }
        let data = try Data(contentsOf: url)
        // Nota: duration se calcularía con AVFoundation si fuera necesario
        return AudioData(data: data, duration: 0)
    }
    
    func delete(path: String) async throws {
        let url = baseDirectory.appendingPathComponent(path)
        try FileManager.default.removeItem(at: url)
    }
    
    func export(path: String, format: AudioFormat, quality: AudioQuality) async throws -> Data {
        let url = baseDirectory.appendingPathComponent(path)
        // Conversión de formato si es necesario
        return try Data(contentsOf: url)
    }
    
    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }
}
```

## Adapters de TTS

### NativeTTSAdapter

```swift
// Infrastructure/Adapters/TTS/NativeTTSAdapter.swift
import AVFoundation

final class NativeTTSAdapter: TTSPort {
    private let synthesizer = AVSpeechSynthesizer()
    
    var isAvailable: Bool { true }
    
    func availableVoices() async -> [Voice] {
        AVSpeechSynthesisVoice.speechVoices().map { avVoice in
            Voice(
                id: avVoice.identifier,
                name: avVoice.name,
                language: avVoice.language,
                provider: .native,
                isDefault: avVoice.identifier == AVSpeechSynthesisVoice.currentLanguageCode()
            )
        }
    }
    
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData {
        return try await withCheckedThrowingContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text.value)
            utterance.rate = Float(voice.speed.value) * AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = Float(voice.pitch.value)
            
            if let avVoice = AVSpeechSynthesisVoice(identifier: voice.voiceId) {
                utterance.voice = avVoice
            }
            
            // Usar AVAudioEngine para capturar audio
            // ... implementación de captura a archivo
            
            // Por simplicidad, esto es un placeholder
            let data = Data()
            let duration: TimeInterval = text.estimatedDuration
            continuation.resume(returning: AudioData(data: data, duration: duration))
        }
    }
}
```

### OpenAITTSAdapter

```swift
// Infrastructure/Adapters/TTS/OpenAITTSAdapter.swift
import Foundation

final class OpenAITTSAdapter: TTSPort {
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    var isAvailable: Bool { !apiKey.isEmpty }
    
    func availableVoices() async -> [Voice] {
        // OpenAI tiene voces fijas
        ["alloy", "echo", "fable", "onyx", "nova", "shimmer"].map { voiceId in
            Voice(
                id: voiceId,
                name: voiceId.capitalized,
                language: "en-US",
                provider: .openAI,
                isDefault: voiceId == "alloy"
            )
        }
    }
    
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData {
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text.value,
            "voice": voice.voiceId,
            "speed": voice.speed.value
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw InfrastructureError.apiError("OpenAI TTS failed")
        }
        
        // Estimar duración basada en el texto
        let duration = text.estimatedDuration
        return AudioData(data: data, duration: duration)
    }
}
```

## Adapters de Audio

### AVFoundationEditorAdapter

```swift
// Infrastructure/Adapters/Audio/AVFoundationEditorAdapter.swift
import AVFoundation

final class AVFoundationEditorAdapter: AudioEditorPort {
    
    func trim(audioPath: String, range: TimeRange) async throws -> String {
        let asset = AVAsset(url: urlFor(audioPath))
        let composition = AVMutableComposition()
        
        guard let track = try await asset.loadTracks(withMediaType: .audio).first,
              let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw InfrastructureError.audioProcessingFailed
        }
        
        let startTime = CMTime(seconds: range.start, preferredTimescale: 44100)
        let duration = CMTime(seconds: range.duration, preferredTimescale: 44100)
        let timeRange = CMTimeRange(start: startTime, duration: duration)
        
        try compositionTrack.insertTimeRange(timeRange, of: track, at: .zero)
        
        let outputPath = generateOutputPath()
        try await export(composition: composition, to: outputPath)
        
        return outputPath
    }
    
    func merge(audioPaths: [String]) async throws -> String {
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        
        for path in audioPaths {
            let asset = AVAsset(url: urlFor(path))
            guard let track = try await asset.loadTracks(withMediaType: .audio).first,
                  let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else {
                continue
            }
            
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try compositionTrack.insertTimeRange(timeRange, of: track, at: currentTime)
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        let outputPath = generateOutputPath()
        try await export(composition: composition, to: outputPath)
        
        return outputPath
    }
    
    func adjustSpeed(audioPath: String, rate: Double) async throws -> String {
        // Implementación con AVFoundation
        fatalError("Not implemented")
    }
    
    func adjustVolume(audioPath: String, factor: Double) async throws -> String {
        // Implementación con AVFoundation
        fatalError("Not implemented")
    }
    
    func fadeIn(audioPath: String, duration: TimeInterval) async throws -> String {
        // Implementación con AVFoundation
        fatalError("Not implemented")
    }
    
    func fadeOut(audioPath: String, duration: TimeInterval) async throws -> String {
        // Implementación con AVFoundation
        fatalError("Not implemented")
    }
    
    // MARK: - Private
    
    private func urlFor(_ path: String) -> URL {
        // Resolver path a URL completa
        fatalError("Not implemented")
    }
    
    private func generateOutputPath() -> String {
        UUID().uuidString + ".m4a"
    }
    
    private func export(composition: AVMutableComposition, to path: String) async throws {
        // Exportar con AVAssetExportSession
        fatalError("Not implemented")
    }
}
```

## Keychain Adapter

```swift
// Infrastructure/Adapters/Security/KeychainAdapter.swift
import Security

final class KeychainAdapter {
    enum Key: String {
        case kokoroServerURL = "com.texttoaudio.kokoro.serverurl"
        case qwen3ServerURL = "com.texttoaudio.qwen3.serverurl"
        // Por si se añaden APIs remotas en el futuro
        case customAPIKey = "com.texttoaudio.custom.apikey"
    }
    
    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw InfrastructureError.keychainError(status)
        }
    }
    
    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

## Errores de Infraestructura

```swift
// Infrastructure/Errors/InfrastructureError.swift

enum InfrastructureError: LocalizedError {
    case fileNotFound(String)
    case apiError(String)
    case networkError(Error)
    case audioProcessingFailed
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Archivo no encontrado: \(path)"
        case .apiError(let message):
            return "Error de API: \(message)"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .audioProcessingFailed:
            return "Error procesando audio"
        case .keychainError(let status):
            return "Error de Keychain: \(status)"
        }
    }
}
```

## Testing de Adapters

```swift
// Tests/Infrastructure/SwiftDataProjectRepositoryTests.swift
import XCTest
import SwiftData
@testable import TextToAudio

final class SwiftDataProjectRepositoryTests: XCTestCase {
    var sut: SwiftDataProjectRepository!
    var container: ModelContainer!
    
    @MainActor
    override func setUp() async throws {
        container = try ModelContainer(
            for: ProjectModel.self, AudioSegmentModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        sut = SwiftDataProjectRepository(modelContainer: container)
    }
    
    @MainActor
    func test_save_shouldPersistProject() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        
        // Act
        try await sut.save(project)
        
        // Assert
        let retrieved = try await sut.findById(project.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, project.name)
    }
    
    @MainActor
    func test_findById_whenNotExists_shouldReturnNil() async throws {
        // Act
        let result = try await sut.findById(ProjectId())
        
        // Assert
        XCTAssertNil(result)
    }
    
    @MainActor
    func test_delete_shouldRemoveProject() async throws {
        // Arrange
        let project = TestFixtures.makeProject()
        try await sut.save(project)
        
        // Act
        try await sut.delete(project.id)
        
        // Assert
        let result = try await sut.findById(project.id)
        XCTAssertNil(result)
    }
}
```

## Archivos a Crear

```
Infrastructure/
├── Adapters/
│   ├── Persistence/
│   │   ├── SwiftData/
│   │   │   ├── Models/
│   │   │   │   ├── ProjectModel.swift
│   │   │   │   └── AudioSegmentModel.swift
│   │   │   ├── Mappers/
│   │   │   │   ├── ProjectMapper.swift
│   │   │   │   └── AudioSegmentMapper.swift
│   │   │   └── SwiftDataProjectRepository.swift
│   │   └── FileSystem/
│   │       └── AudioFileStorage.swift
│   │
│   ├── TTS/
│   │   ├── NativeTTSAdapter.swift
│   │   ├── OpenAITTSAdapter.swift
│   │   └── ElevenLabsTTSAdapter.swift
│   │
│   ├── Audio/
│   │   ├── AVFoundationEditorAdapter.swift
│   │   ├── AVFoundationPlayerAdapter.swift
│   │   └── WaveformGeneratorAdapter.swift
│   │
│   └── Security/
│       └── KeychainAdapter.swift
│
├── Errors/
│   └── InfrastructureError.swift
│
└── Configuration/
    └── EnvironmentConfig.swift
```

## Checklist de Calidad

- [ ] Adapters solo importan frameworks necesarios
- [ ] Adapters implementan Ports del dominio
- [ ] Mappers convierten entre modelos de infra y dominio
- [ ] Errores son específicos de infraestructura
- [ ] Tests de integración para cada adapter
- [ ] No hay lógica de negocio en adapters
