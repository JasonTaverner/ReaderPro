# Agente: Audio & TTS Specialist

## Rol
Especialista en implementación de Adapters de audio y TTS. Implementa los Ports definidos en el dominio (`TTSPort`, `AudioEditorPort`, `AudioPlayerPort`) usando frameworks de Apple y modelos TTS locales.

## Ubicación
`agents/audio-agent.md`

## Responsabilidades

### Implementar Ports de TTS
- `NativeTTSAdapter` - AVSpeechSynthesizer (básico, offline)
- `KokoroTTSAdapter` - Kokoro TTS (alta calidad, local)
- `Qwen3TTSAdapter` - Qwen3-TTS (muy natural, local/API)

### Implementar Ports de Audio
- `AVFoundationEditorAdapter` - Edición de audio
- `AVFoundationPlayerAdapter` - Reproducción
- `WaveformGeneratorAdapter` - Visualización

## Proveedores de TTS

### 1. Kokoro TTS
**Descripción:** Modelo TTS open source de alta calidad, ejecutable localmente.

- **Repo:** https://github.com/hexgrad/kokoro
- **Características:**
  - 82M parámetros
  - Múltiples voces y estilos
  - Soporta inglés, español, francés, y más
  - Ejecutable en CPU/GPU
  - Apache 2.0 license

**Integración en macOS:**
```swift
// Opción 1: Via Python subprocess
// Opción 2: Via servidor local HTTP
// Opción 3: Convertir a CoreML (avanzado)
```

### 2. Qwen3-TTS
**Descripción:** Modelo TTS de Alibaba, voces muy naturales.

- **Modelo:** Qwen2.5-Omni / CosyVoice
- **Características:**
  - Zero-shot voice cloning
  - Múltiples idiomas
  - Emociones y estilos
  - Ejecutable localmente con Ollama o via API

**Integración:**
```swift
// Opción 1: Ollama local
// Opción 2: API de Alibaba Cloud
// Opción 3: Servidor local con transformers
```

### 3. Nativo (AVSpeechSynthesizer)
**Descripción:** TTS integrado de Apple, básico pero siempre disponible.

- Sin dependencias externas
- Funciona offline
- Calidad limitada pero consistente

## Principio Fundamental

> **Los Adapters implementan Ports. Solo ellos importan frameworks de audio.**

```swift
// ✅ CORRECTO
// Infrastructure/Adapters/TTS/KokoroTTSAdapter.swift
import Foundation

final class KokoroTTSAdapter: TTSPort {
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData
}

// ❌ INCORRECTO
// Domain/AudioGeneration/Ports/TTSPort.swift
import SomeExternalFramework  // NUNCA en Domain
```

## Ports a Implementar (definidos en Domain)

```swift
// Domain/AudioGeneration/Ports/TTSPort.swift
protocol TTSPort {
    var isAvailable: Bool { get }
    func availableVoices() async -> [Voice]
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData
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

// Domain/Playback/Ports/AudioPlayerPort.swift
protocol AudioPlayerPort {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    
    func load(path: String) async throws
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func setPlaybackRate(_ rate: Float)
}
```

## Formatos de Audio

### Interno (Almacenamiento)
- **M4A (AAC)** - Buen balance calidad/tamaño
- Bitrate: 256 kbps
- Sample rate: 44.1 kHz

### Exportación
```swift
enum AudioFormat: String, CaseIterable {
    case mp3 = "MP3"
    case wav = "WAV"
    case m4a = "M4A"
    case aiff = "AIFF"
}

enum AudioQuality: String, CaseIterable {
    case low = "Baja (128 kbps)"
    case medium = "Media (192 kbps)"
    case high = "Alta (256 kbps)"
    case lossless = "Sin pérdida"
}
```

## Generación de Waveform

```swift
class WaveformGenerator {
    func generateWaveform(from url: URL, samples: Int = 200) async throws -> [Float] {
        // Usar AVAudioFile para leer
        // Procesar buffer para extraer amplitudes
        // Devolver array normalizado de 0 a 1
    }
}
```

## Manejo de Errores

```swift
enum AudioError: LocalizedError {
    case synthesizeFailed(String)
    case fileNotFound
    case invalidFormat
    case exportFailed
    case networkError(Error)
    case apiKeyMissing
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .synthesizeFailed(let reason):
            return "Error al sintetizar audio: \(reason)"
        // ... etc
        }
    }
}
```

## Consideraciones de Rendimiento

### Background Processing
```swift
func synthesize(text: String, voice: Voice) async throws -> URL {
    return try await Task.detached(priority: .userInitiated) {
        // Procesamiento pesado aquí
    }.value
}
```

### Caché
- Cachear audios generados por hash de texto+voz
- Límite de caché configurable (default 500 MB)
- LRU eviction policy

### Streaming (Avanzado)
- Para textos largos, considerar streaming
- Generar por segmentos y unir
- Mostrar progreso al usuario

## Testing

### Unit Tests
```swift
class AudioServiceTests: XCTestCase {
    func testNativeTTSGeneratesAudio() async throws {
        let service = NativeTTSService()
        let url = try await service.synthesize(text: "Hola mundo", voice: .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    
    func testAudioTrimming() async throws {
        let editing = AudioEditingService()
        let trimmed = try await editing.trim(audio: testAudioURL, from: 1.0, to: 3.0)
        // Verificar duración
    }
}
```

### Mocks para Testing
```swift
class MockTTSService: TTSServiceProtocol {
    var shouldFail = false
    var delay: TimeInterval = 0
    
    func synthesize(text: String, voice: Voice) async throws -> URL {
        if shouldFail { throw AudioError.synthesizeFailed("Mock error") }
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return Bundle.main.url(forResource: "test_audio", withExtension: "mp3")!
    }
}
```

## Archivos a Crear

```
Infrastructure/Adapters/
├── TTS/
│   ├── NativeTTSAdapter.swift        # Implementa TTSPort (AVSpeechSynthesizer)
│   ├── KokoroTTSAdapter.swift        # Implementa TTSPort (Kokoro local)
│   ├── Qwen3TTSAdapter.swift         # Implementa TTSPort (Qwen3-TTS)
│   └── LocalTTSServer.swift          # Servidor HTTP local para modelos Python
│
├── Audio/
│   ├── AVFoundationEditorAdapter.swift   # Implementa AudioEditorPort
│   ├── AVFoundationPlayerAdapter.swift   # Implementa AudioPlayerPort
│   └── WaveformGeneratorAdapter.swift
│
└── Errors/
    └── AudioAdapterError.swift

Tests/Infrastructure/
├── NativeTTSAdapterTests.swift
├── KokoroTTSAdapterTests.swift
├── Qwen3TTSAdapterTests.swift
├── AVFoundationEditorAdapterTests.swift
└── AVFoundationPlayerAdapterTests.swift
```

## Integración de Modelos Locales

### Kokoro TTS - Servidor Local

```swift
// Infrastructure/Adapters/TTS/KokoroTTSAdapter.swift
import Foundation

final class KokoroTTSAdapter: TTSPort {
    private let serverURL: URL
    private let session: URLSession
    
    init(serverURL: URL = URL(string: "http://localhost:8880")!, 
         session: URLSession = .shared) {
        self.serverURL = serverURL
        self.session = session
    }
    
    var isAvailable: Bool {
        // Verificar si el servidor Kokoro está corriendo
        get async {
            do {
                let (_, response) = try await session.data(from: serverURL.appendingPathComponent("health"))
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }
        }
    }
    
    func availableVoices() async -> [Voice] {
        // Kokoro tiene voces predefinidas por estilo
        [
            Voice(id: "af_heart", name: "Heart (Female)", language: "en-US", provider: .kokoro, isDefault: true),
            Voice(id: "af_bella", name: "Bella (Female)", language: "en-US", provider: .kokoro, isDefault: false),
            Voice(id: "am_adam", name: "Adam (Male)", language: "en-US", provider: .kokoro, isDefault: false),
            Voice(id: "am_michael", name: "Michael (Male)", language: "en-US", provider: .kokoro, isDefault: false),
            Voice(id: "ef_emma", name: "Emma (Female, British)", language: "en-GB", provider: .kokoro, isDefault: false),
            Voice(id: "es_isabella", name: "Isabella (Spanish)", language: "es-ES", provider: .kokoro, isDefault: false),
        ]
    }
    
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData {
        let url = serverURL.appendingPathComponent("synthesize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text.value,
            "voice": voice.voiceId,
            "speed": voice.speed.value
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TTSAdapterError.synthesizeFailed("Kokoro server error")
        }
        
        // Calcular duración del audio
        let duration = try await calculateDuration(from: data)
        return AudioData(data: data, duration: duration)
    }
    
    private func calculateDuration(from data: Data) async throws -> TimeInterval {
        // Escribir a archivo temporal y usar AVFoundation
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let asset = AVURLAsset(url: tempURL)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
}
```

### Qwen3-TTS - Via Ollama

```swift
// Infrastructure/Adapters/TTS/Qwen3TTSAdapter.swift
import Foundation

final class Qwen3TTSAdapter: TTSPort {
    private let ollamaURL: URL
    private let session: URLSession
    
    init(ollamaURL: URL = URL(string: "http://localhost:11434")!, 
         session: URLSession = .shared) {
        self.ollamaURL = ollamaURL
        self.session = session
    }
    
    var isAvailable: Bool {
        get async {
            // Verificar si Ollama está corriendo y tiene el modelo
            do {
                let url = ollamaURL.appendingPathComponent("api/tags")
                let (data, _) = try await session.data(from: url)
                let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
                return response.models.contains { $0.name.contains("qwen") }
            } catch {
                return false
            }
        }
    }
    
    func availableVoices() async -> [Voice] {
        // Qwen3-TTS puede clonar voces, pero tiene voces base
        [
            Voice(id: "default", name: "Qwen Default", language: "multi", provider: .qwen3, isDefault: true),
            Voice(id: "chinese", name: "Chinese Native", language: "zh-CN", provider: .qwen3, isDefault: false),
            Voice(id: "english", name: "English Native", language: "en-US", provider: .qwen3, isDefault: false),
            Voice(id: "spanish", name: "Spanish Native", language: "es-ES", provider: .qwen3, isDefault: false),
        ]
    }
    
    func synthesize(text: Text, voice: VoiceConfiguration) async throws -> AudioData {
        // Qwen3 via CosyVoice o endpoint personalizado
        let url = ollamaURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Nota: La integración real dependerá de cómo se sirva Qwen3-TTS
        // Esto es un ejemplo conceptual
        let body: [String: Any] = [
            "model": "qwen2.5-omni",  // o el modelo TTS específico
            "prompt": text.value,
            "voice": voice.voiceId,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TTSAdapterError.synthesizeFailed("Qwen3 TTS error")
        }
        
        // Parsear respuesta y extraer audio
        let duration = text.estimatedDuration
        return AudioData(data: data, duration: duration)
    }
}

// Helper structs
private struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

private struct OllamaModel: Codable {
    let name: String
}
```

### Servidor Python para TTS (Helper Script)

```python
# scripts/tts_server.py
# Ejecutar con: python tts_server.py

from flask import Flask, request, send_file
import kokoro
import io

app = Flask(__name__)

# Cargar modelo Kokoro una vez
model = kokoro.KokoroTTS()

@app.route('/health')
def health():
    return {'status': 'ok'}

@app.route('/synthesize', methods=['POST'])
def synthesize():
    data = request.json
    text = data.get('text', '')
    voice = data.get('voice', 'af_heart')
    speed = data.get('speed', 1.0)
    
    # Generar audio
    audio = model.generate(text, voice=voice, speed=speed)
    
    # Devolver como WAV
    buffer = io.BytesIO()
    audio.save(buffer, format='wav')
    buffer.seek(0)
    
    return send_file(buffer, mimetype='audio/wav')

if __name__ == '__main__':
    app.run(port=8880)
```

## Configuración de Modelos Locales

### Setup Kokoro
```bash
# Instalar Kokoro
pip install kokoro-tts

# O clonar y construir
git clone https://github.com/hexgrad/kokoro
cd kokoro
pip install -e .

# Ejecutar servidor
python scripts/tts_server.py
```

### Setup Qwen3-TTS via Ollama
```bash
# Instalar Ollama
brew install ollama

# Descargar modelo (cuando esté disponible)
ollama pull qwen2.5-omni

# O usar CosyVoice
pip install cosyvoice
```

## Interacción con Otros Agentes

- **Implementa:** Ports definidos por el Agente de Arquitectura
- **Usado por:** Use Cases de la capa Application
- **Provee a:** UI Presenters (via Use Cases) datos de audio

## Consideraciones para Modelos Locales

### Rendimiento
- Kokoro: ~100ms por frase en M1/M2
- Qwen3: Varía según modelo y hardware
- Considerar caché de audios generados

### Gestión de Recursos
```swift
// Verificar disponibilidad antes de usar
func selectBestTTSProvider() async -> TTSPort {
    if await kokoroAdapter.isAvailable {
        return kokoroAdapter
    } else if await qwen3Adapter.isAvailable {
        return qwen3Adapter
    } else {
        return nativeAdapter
    }
}
```

### Fallback
Siempre tener `NativeTTSAdapter` como fallback si los modelos locales no están disponibles.

## Checklist de Calidad

- [ ] Adapters implementan correctamente los Ports
- [ ] Solo los Adapters importan frameworks externos
- [ ] Tests de integración para cada Adapter
- [ ] Servidor local de TTS funciona correctamente
- [ ] Fallback a TTS nativo implementado
- [ ] Manejo de errores cuando modelos no están disponibles
- [ ] La reproducción es fluida sin cortes
- [ ] El waveform se genera correctamente
