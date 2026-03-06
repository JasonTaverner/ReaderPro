# User Guide

End-user manual for ReaderPro.

## Overview

ReaderPro converts text to high-quality audio using local AI models. Create projects, generate audio entries, and manage your audio library.

## Main Window — Project List

The main window shows all your projects as cards.

**Actions:**
- **"+" button** — Create a new project
- **Search bar** — Filter projects by name or content
- **Right-click a project** — Context menu: Delete, Show in Finder
- **Click a project** — Open in editor

## Project Editor

The editor has two panels:

### Left Panel — Content

- **Text Editor** — Write or paste text for audio generation
- **Entry Grid** — Shows all audio entries (text + image + audio)
- **Audio Player** — Waveform, playback controls, speed selector

### Right Sidebar — Configuration

- **Project Name** — Editable
- **Voice Selector** — Choose from available voices
- **Speed** — 0.5x to 2.0x (slider)
- **Pitch** — 0.5x to 2.0x (slider)

**Qwen3-only controls (when Qwen3 selected):**
- **Accent** — Choose accent for VoiceDesign mode
- **Gender** — Male/Female (appears when accent selected)
- **Emotion** — Preset emotions or custom style instruction
- **Voice Clone** — Clone a voice from a reference audio file

### Action Buttons

| Button | Description |
|---|---|
| Save Changes | Manually save (also auto-saves after 2s) |
| Capture Screen | Screenshot OCR (Cmd+Shift+S) |
| Import Images | Batch OCR from image files |
| Import Document | Process PDF or EPUB |
| Import Text | Split long text into entries |
| Generate Audio | Generate audio for current text |
| Export Project | Create merged export (Fusion folder) |
| Show in Finder | Open project folder |

## Audio Playback

- Click an entry's play button to start playback
- **Waveform** — Drag to seek
- **Skip buttons** — Jump 10 seconds forward/back
- **Speed presets** — 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
- **Auto-play** — Automatically play next entry when current finishes
- **Previous/Next** — Navigate between entries

## TTS Providers

Switch providers using the dropdown in the main toolbar area. The app manages server processes automatically.

### Kokoro (Default)

High-quality English TTS. Works offline with ONNX model.

### Qwen3

Natural-sounding TTS with:
- 9 premium voices (CustomVoice mode)
- Multi-language accents (VoiceDesign mode)
- Voice cloning from reference audio

## Voice Cloning

1. Select Qwen3 as provider
2. Enable "Voice Clone" in sidebar
3. Click "Select Audio" and choose a WAV/MP3 file (minimum 3 seconds)
4. Generate audio — it will use the cloned voice

**Note:** Voice cloning and accent selection are mutually exclusive.

## Screen Capture & OCR

1. Click "Capture Screen" or press Cmd+Shift+S
2. Select a region of your screen
3. Text is automatically extracted via OCR
4. A new entry is created with the text and screenshot image

## Importing Documents

### Images
Select multiple images — OCR extracts text from each, creating one entry per image.

### PDF
Each page is rendered and OCR'd, creating one entry per page.

### Text
Paste or import a long text file — it's split into multiple entries for easier processing.

## Project Export

Click "Export Project" to create a merged folder containing:
- All texts in one file
- All audio merged into one WAV
- All images combined into one PDF

The folder appears inside your project directory as `Fusion_001/`, `Fusion_002/`, etc.

## Settings

Access via **ReaderPro > Settings** (Cmd+,).

### Storage
- View or change the project storage directory
- Default: `~/Documents/ReaderProLibrary/`

### TTS Memory
- See which Qwen3 model is loaded
- Free memory by unloading the model
- Check server status (online/offline)

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New project |
| Cmd+Shift+S | Capture screen |
| Cmd+, | Settings |
