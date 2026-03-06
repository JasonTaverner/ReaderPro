# TTS: Kokoro

Kokoro is a lightweight, high-quality TTS model (82M parameters). ReaderPro supports two modes: **local ONNX inference** and a **remote Python server**.

## Modes

### Local ONNX (Default)

Native Swift inference using ONNX Runtime with CoreML execution provider. No Python or server needed.

**Pipeline:**
```
Input Text
    ↓
EspeakPhonemizer → IPA Phonemes
    ↓
KokoroTokenizer → Token IDs [0, t1, t2, ..., 0]
    ↓
VoiceEmbeddingStore → Style Vector (510 × 256 floats)
    ↓
KokoroONNXEngine.infer() → Audio Samples (Float32)
    ↓
AudioTrimmer → Trim Silence
    ↓
WAVEncoder → WAV Binary (24kHz mono)
    ↓
Output: AudioData
```

**Components:**

| File | Responsibility |
|---|---|
| `KokoroONNXAdapter.swift` | TTSPort implementation, batch processing |
| `KokoroONNXEngine.swift` | ONNX Runtime session, inference |
| `EspeakPhonemizer.swift` | Text → IPA via espeak-ng (dlopen) |
| `KokoroTokenizer.swift` | IPA → token IDs (114-entry vocab) |
| `VoiceEmbeddingStore.swift` | Load voice embeddings from NPZ file |
| `AudioTrimmer.swift` | Remove trailing silence |
| `WAVEncoder.swift` | Encode Float32 samples to WAV |
| `NpyParser.swift` | Parse NumPy .npy binary format |

**Model files:**
- `scripts/Resources/Models/kokoro/kokoro-v1.0.onnx` (~330MB)
- `scripts/Resources/Models/kokoro/voices-v1.0.bin` (NPZ archive with voice embeddings)

**espeak-ng resources:**
- `ReaderPro/Resources/espeak-ng/lib/libespeak-ng.dylib`
- `ReaderPro/Resources/espeak-ng/share/espeak-ng-data/`

**ONNX Runtime:**
- SPM dependency: `microsoft/onnxruntime-swift-package-manager` v1.20.0
- CoreML execution provider for GPU/ANE acceleration
- Falls back to CPU if CoreML unavailable

### Remote Server

Python server using `kokoro-onnx` library.

**Server:** `scripts/kokoro_server.py` at `localhost:8880`

**Endpoint:** `POST /synthesize`
```json
{
  "text": "Hello world",
  "voice": "af_bella",
  "speed": 1.0
}
```
Response: WAV binary data

**Health check:** `GET /health`

**Server management:** `KokoroServerManager` launches the Python process and monitors health.

## Voice Embeddings

Voices are stored in `voices-v1.0.bin` (a ZIP/NPZ archive). Each voice is a `.npy` file containing a float32 array of shape `(510, 1, 256)`.

**Voice ID format:** `{gender}{language}_{name}`
- `af_bella` — American Female Bella
- `bm_george` — British Male George
- `jf_alpha` — Japanese Female Alpha

The `VoiceEmbeddingStore` extracts and caches embeddings on demand.

## Tokenizer Details

Character-level tokenizer with 114 entries mapping IPA symbols to token IDs (embedding table size: 178).

**Token processing:**
1. Truncate phonemes to max 510 characters
2. Map each IPA character to vocab ID (unknown chars dropped)
3. Add padding: `[0] + tokens + [0]`

**Batching:** For texts longer than 510 phonemes, `KokoroONNXAdapter.splitPhonemes()` splits at punctuation boundaries. Each batch is inferred separately and audio is concatenated.

## Audio Output

- **Format:** WAV
- **Sample rate:** 24,000 Hz
- **Channels:** Mono
- **Bit depth:** 16-bit (from Float32 via WAVEncoder)

## Switching Modes

`TTSServerCoordinator` manages the `KokoroMode`:

```swift
enum KokoroMode {
    case localONNX      // Default if model files available
    case remoteServer   // Falls back if ONNX unavailable
}
```

The mode is selected automatically based on model file availability, but can be overridden by the user.

## Languages Supported

Via espeak-ng phonemizer: English (US/GB), Spanish, French, German, Italian, Portuguese, Japanese, Korean, Chinese, and more.
