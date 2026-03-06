# TTS: Qwen3

Qwen3-TTS is Alibaba's text-to-speech model, running locally via an MLX-based Python server. Supports three modes: **CustomVoice**, **VoiceDesign**, and **Voice Cloning**.

## Server

**Script:** `scripts/qwen3_mlx_server.py`
**Port:** `localhost:8890`
**Framework:** Flask + MLX-Audio

### Model Management

The server uses a `ModelManager` that keeps **only one model in memory** at a time, unloading the previous when switching:

| Mode | Model | Size |
|---|---|---|
| **CustomVoice** | `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice` | ~4GB |
| **VoiceDesign** | `mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit` | ~1GB |
| **Base (Cloning)** | `mlx-community/Qwen3-TTS-12Hz-1.7B-bf16` | ~4GB |

### Endpoints

**`POST /synthesize`**
```json
{
  "text": "Hello world",
  "speaker": "Chelsie",
  "mode": "custom_voice",
  "lang_code": "auto",
  "instruct": null,
  "voice_design_instruct": null,
  "voice_design_language": "es"
}
```

**`POST /clone`** (multipart form data)
- `audio` — reference WAV/MP3 file (min 3 seconds)
- `text` — text to synthesize

**`POST /unload`** — Free model memory

**`GET /health`** — Server status + loaded model name

## Modes

### CustomVoice

Uses 9 premium voices with natural speech quality:

| Voice | Gender | Style |
|---|---|---|
| Chelsie | Female | Warm, conversational |
| Aidan | Male | Clear, authoritative |
| Luna | Female | Soft, gentle |
| Mia | Female | Energetic, bright |
| Josh | Male | Deep, calm |
| Elena | Female | Elegant, refined |
| Aria | Female | Versatile, expressive |
| Marcus | Male | Strong, confident |
| Zara | Female | Dynamic, engaging |

**When:** No accent selected, no clone audio, no voice design instruct.

### VoiceDesign

For languages without native CustomVoice speakers (Spanish, French, German, etc.). Uses a descriptive instruct to synthesize voice characteristics.

**Instruct format:**
```
Describe a woman around 30 years old with a warm, clear female voice.
She speaks with a native Castilian Spanish accent.
The voice sounds natural and pleasant.
```

**With emotion:**
```
Describe a man around 35 years old with a deep, resonant male voice.
He speaks with a native French accent. Speaking softly and calmly.
```

**When:** `VoiceConfiguration.voiceDesignInstruct` is non-nil (set when user selects an accent in AccentSelectorView).

**Supported accents:**
- Spanish: Spain, Mexico, Argentina
- French, German, Italian
- Portuguese: Brazil, Portugal
- Russian

**Language code:** Set via `VoiceConfiguration.voiceDesignLanguage` to ensure correct pronunciation (e.g., `es` instead of `auto`).

### Voice Cloning

Clones a voice from a reference audio sample (minimum 3 seconds).

**When:** `VoiceConfiguration.referenceAudioURL` is non-nil.

**Flow:**
1. User enables clone mode in VoiceCloneView
2. Selects a WAV/MP3 reference file (validated ≥ 3s)
3. On generation, adapter sends multipart request to `/clone`
4. Server loads Base model, processes reference + text
5. Returns synthesized audio in cloned voice

**Mutual exclusivity:** Clone mode and VoiceDesign (accent) cannot be active simultaneously. The UI enforces this — enabling clone clears accent, selecting accent disables clone.

## Integration

### Qwen3TTSAdapter

Implements `TTSPort`. Determines mode from `VoiceConfiguration` fields:

```swift
func synthesize(text: TextContent, voiceConfiguration: VoiceConfiguration, voice: Voice) async throws -> AudioData {
    if let referenceURL = voiceConfiguration.referenceAudioURL {
        return try await cloneVoice(text: text, referenceURL: referenceURL)
    } else if let designInstruct = voiceConfiguration.voiceDesignInstruct {
        return try await synthesizeWithDesign(text: text, instruct: designInstruct, ...)
    } else {
        return try await synthesizeCustomVoice(text: text, speaker: voice.id, ...)
    }
}
```

### Qwen3ServerManager

Launches and monitors the Python server process. Searches for the script in multiple locations (Bundle, SOURCE_ROOT, relative paths).

## Memory Management

- `ModelManager` loads only 1 model at a time
- Switching modes automatically unloads the previous model
- Manual unload via `POST /unload` or Settings > TTS Memory > Free Memory
- VoiceDesign uses 4-bit quantization (~1GB vs ~4GB for full models)

## UI Controls (Qwen3-only)

These controls appear in ProjectDetailView's sidebar only when Qwen3 is the active provider:

- **AccentSelectorView** — Chip buttons for accent selection, gender toggle
- **EmotionSelectorView** — Emotion presets + custom instruct text field
- **VoiceCloneView** — Toggle + file picker for reference audio
