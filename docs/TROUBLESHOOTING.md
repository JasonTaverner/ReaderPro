# Troubleshooting

Common issues and solutions.

## Build Issues

### SPM dependency resolution fails

**Symptoms:** Xcode shows package resolution errors for ONNX Runtime.

**Fix:**
1. Close Xcode
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/`
3. Delete package cache: `rm -rf ~/Library/Caches/org.swift.swiftpm/`
4. Reopen project and let Xcode resolve packages

### `NSWorkspace` not found / Cannot find type in scope

**Cause:** Missing `import AppKit` in Swift files that use macOS APIs.

**Fix:** Add `import AppKit` at the top of the file.

### SourceKit errors for domain types

**Symptoms:** "Cannot find type 'EditorViewModel' in scope" etc., but builds succeed.

**Cause:** SourceKit indexing issues in Xcode projects (not SPM-based). These are IDE-only errors.

**Fix:** Build the project (Cmd+B). If it succeeds, ignore SourceKit errors. Clean build folder (Cmd+Shift+K) can help.

## TTS Issues

### Kokoro ONNX: "Model not found"

**Cause:** ONNX model file not in expected location.

**Fix:** Ensure these files exist:
```
scripts/Resources/Models/kokoro/kokoro-v1.0.onnx
scripts/Resources/Models/kokoro/voices-v1.0.bin
```

### Kokoro ONNX: espeak-ng initialization fails

**Cause:** espeak-ng dynamic library or data not found.

**Fix:** Ensure these exist:
```
ReaderPro/Resources/espeak-ng/lib/libespeak-ng.dylib
ReaderPro/Resources/espeak-ng/share/espeak-ng-data/
```

### Kokoro Server: Connection refused on port 8880

**Cause:** Python server not running.

**Fix:**
```bash
pip install kokoro-onnx flask soundfile numpy
python scripts/kokoro_server.py
```

### Qwen3: Connection refused on port 8890

**Cause:** MLX server not running.

**Fix:**
```bash
pip install mlx-audio flask soundfile numpy
python scripts/qwen3_mlx_server.py
```

### Qwen3: Male voices sound female

**Cause:** VoiceDesign instruct not descriptive enough for gender differentiation.

**Fix:** The instruct format uses rich descriptors: "Describe a man around 35 years old with a deep, resonant male voice..." Make sure the VoiceDesign instruct includes explicit gender markers.

### Qwen3: Wrong language/accent

**Cause:** `lang_code` defaulting to `auto` instead of specific language.

**Fix:** The `VoiceConfiguration.voiceDesignLanguage` field must be set (e.g., `es`, `fr`, `de`) when using VoiceDesign mode. This is handled automatically by AccentSelectorView.

### Provider switches to Kokoro when opening project

**Cause (historical):** `EditorPresenter.loadProject()` was overriding the global provider selection with the project's saved provider.

**Fix:** The presenter no longer switches providers on project load. The user's current global provider selection is preserved.

## Audio Playback Issues

### No sound / playback fails

**Check:**
1. Audio file exists at the path shown in the entry
2. File is a valid WAV (24kHz, mono)
3. macOS audio output is not muted
4. Try "Show in Finder" and play the WAV file directly

### Waveform not showing

**Cause:** Waveform generation failed (corrupt audio file or file not found).

**Fix:** Regenerate audio for the entry.

## Project Issues

### Projects not appearing in list

**Check:**
1. Storage directory exists: `~/Documents/ReaderProLibrary/`
2. Each project folder has a `project.json` file
3. JSON file is valid (not corrupt)

### "Show in Finder" does nothing

**Cause:** Project directory doesn't exist on disk.

**Fix:** The project may have been moved or deleted outside the app. Delete and recreate.

### Storage directory changed but old projects missing

**Cause:** Projects are stored in the old directory.

**Fix:** Move project folders from the old directory to the new one, then restart the app.

## Memory Issues

### High memory usage with Qwen3

**Cause:** TTS model loaded in memory (~4GB for full models).

**Fix:**
1. Go to Settings > TTS Memory
2. Click "Free Memory" to unload the model
3. The VoiceDesign model (4-bit) uses ~1GB vs ~4GB for full models

### App becomes slow

**Fix:**
1. Free TTS memory in Settings
2. Close and reopen the app
3. For large projects with many entries, consider splitting into multiple projects

## Server Issues

### Python server crashes

**Check:**
1. Python version: `python --version` (need 3.10+)
2. Dependencies installed: `pip list | grep -E "mlx|flask|soundfile"`
3. Run server manually in terminal to see error output
4. Check available disk space (models need ~4GB)

### Server script not found

**Cause:** `KokoroServerManager` or `Qwen3ServerManager` can't locate the Python script.

**Fix:** The managers search in multiple locations:
1. App Bundle
2. `SOURCE_ROOT` environment variable
3. Relative paths from the app
4. Parent directories

Ensure scripts are in `scripts/` directory relative to the project root.
