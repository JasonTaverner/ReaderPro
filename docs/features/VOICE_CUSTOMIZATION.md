# Voice Customization

ReaderPro offers extensive voice customization through three systems: **voice selection**, **VoiceDesign** (accent + gender + emotion), and **voice cloning**.

## Voice Selection

### VoiceSelectorView

Menu picker showing all available voices from the active TTS provider.

**Kokoro voices:** Multiple voices with `{gender}{language}_{name}` format (e.g., `af_bella`, `bm_george`).

**Qwen3 CustomVoice voices:** 9 premium voices — Chelsie, Aidan, Luna, Mia, Josh, Elena, Aria, Marcus, Zara.

Voice list is loaded dynamically from the active TTSPort when the project loads or the provider changes.

## Speed & Pitch

Adjustable via sliders in ProjectDetailView sidebar.

| Parameter | Range | Default |
|---|---|---|
| Speed | 0.5x – 2.0x | 1.0x |
| Pitch | 0.5x – 2.0x | 1.0x |

## VoiceDesign (Qwen3 only)

For languages without native CustomVoice speakers. Uses a descriptive prompt to synthesize specific voice characteristics.

### Accent Selection

**AccentSelectorView** displays chip buttons with flag emojis:

| Accent | Language Code | Flag |
|---|---|---|
| Spanish (Spain) | es | 🇪🇸 |
| Spanish (Mexico) | es | 🇲🇽 |
| Spanish (Argentina) | es | 🇦🇷 |
| French | fr | 🇫🇷 |
| German | de | 🇩🇪 |
| Italian | it | 🇮🇹 |
| Portuguese (Brazil) | pt | 🇧🇷 |
| Portuguese (Portugal) | pt | 🇵🇹 |
| Russian | ru | 🇷🇺 |

Selecting "No accent" returns to CustomVoice mode.

### Gender Selection

Appears when an accent is selected. Two options: **Male** and **Female**.

The gender affects the voice description instruct:
- **Female:** "Describe a woman around 30 years old with a warm, clear female voice..."
- **Male:** "Describe a man around 35 years old with a deep, resonant male voice..."

### Emotion / Style

**EmotionSelectorView** provides preset emotions:

| Emotion | Instruct Appended |
|---|---|
| Neutral | (none — "natural and pleasant") |
| Happy | "Speaking happily." |
| Sad | "Speaking sadly." |
| Angry | "Speaking angrily." |
| Whisper | "Speaking in a whisper." |
| Excited | "Speaking excitedly." |
| Calm | "Speaking calmly." |
| Fearful | "Speaking fearfully." |

A custom instruction text field allows free-form style descriptions.

### Complete Instruct Example

```
Describe a woman around 30 years old with a warm, clear female voice.
She speaks with a native Castilian Spanish accent. Speaking calmly.
```

This string is set as `VoiceConfiguration.voiceDesignInstruct` and sent to the Qwen3 server's VoiceDesign model.

## Voice Cloning (Qwen3 only)

### VoiceCloneView

Allows cloning a voice from a reference audio sample.

**Requirements:**
- Audio file: WAV or MP3
- Minimum duration: 3 seconds
- File selected via NSOpenPanel

**UI:**
1. Toggle "Enable voice cloning"
2. "Select Audio" button opens file picker
3. Shows file name, duration, and clear button
4. Error message if audio is too short

**On generation:**
- Reference audio sent as multipart form data to `POST /clone`
- Qwen3 server loads the Base model (bf16)
- Synthesizes text in the cloned voice

### Mutual Exclusivity

VoiceDesign (accent) and Voice Cloning are **mutually exclusive** because they use different Qwen3 models:

| Action | Clears |
|---|---|
| Select accent | Disables clone mode, clears reference audio |
| Enable clone mode | Clears selected accent, clears custom voice description |

This is enforced via `Binding` proxies in ProjectDetailView:

```swift
private var cloneModeBinding: Binding<Bool> {
    Binding(
        get: { presenter.viewModel.isCloneMode },
        set: {
            presenter.viewModel.isCloneMode = $0
            if $0 {
                presenter.viewModel.selectedAccent = ""
                presenter.viewModel.voiceDesignCustom = ""
            }
        }
    )
}
```

## VoiceConfiguration Building

The `EditorPresenter.buildCurrentVoiceConfiguration()` method assembles the final `VoiceConfiguration` from all ViewModel state:

1. Read selected voice ID, speed, pitch
2. Read emotion/custom instruct
3. If accent selected → build VoiceDesign instruct via `VoiceAccent.voiceDesignInstruct(gender:style:)`
4. If clone mode → attach reference audio URL
5. Return complete `VoiceConfiguration`

This configuration is passed to every audio generation call (single entry, batch, etc.).
