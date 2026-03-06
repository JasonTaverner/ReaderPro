# Development Setup

## Prerequisites

| Requirement | Version | Purpose |
|---|---|---|
| macOS | 14.0+ (Sonoma) | Target OS |
| Xcode | 15+ | Build system |
| Apple Silicon | M1/M2/M3/M4 | Recommended for local TTS |
| Python | 3.10+ | Qwen3-TTS server (optional) |
| espeak-ng | Latest | Phonemizer for Kokoro ONNX |

## Clone and Build

```bash
git clone <repo-url>
cd ReaderPro
open ReaderPro.xcodeproj
```

In Xcode: select the `ReaderPro` scheme, then **Cmd+R** to build and run.

The app creates `~/Documents/ReaderProLibrary/` on first launch.

## SPM Dependencies

Resolved automatically by Xcode on first build:

| Package | Version | Purpose |
|---|---|---|
| `onnxruntime-swift-package-manager` | 1.20.0 | ONNX Runtime for Kokoro local inference |

## TTS Providers Setup

### Kokoro ONNX (Local — Default)

No additional setup needed if model files are present:

```
scripts/Resources/Models/kokoro/
├── kokoro-v1.0.onnx      (~330MB)
└── voices-v1.0.bin        (voice embeddings)
```

espeak-ng resources must be in:
```
ReaderPro/Resources/espeak-ng/
├── lib/libespeak-ng.dylib
└── share/espeak-ng-data/
```

### Kokoro Server (Remote)

```bash
pip install kokoro-onnx flask soundfile numpy
python scripts/kokoro_server.py
# Server starts at localhost:8880
```

### Qwen3-TTS

```bash
pip install mlx-audio flask soundfile numpy
python scripts/qwen3_mlx_server.py
# Server starts at localhost:8890
# Models download automatically on first use (~4GB)
```

## Project Structure

```
ReaderPro/
├── App/                      # Entry point, DependencyContainer
├── Domain/                   # Business logic (no dependencies)
├── Application/              # Use Cases, DTOs
├── Infrastructure/           # Adapters (TTS, Audio, Persistence, OCR)
├── UI/                       # SwiftUI Views, Presenters, ViewModels
├── Tests/                    # Unit and integration tests
├── Resources/                # Assets, espeak-ng data
├── scripts/                  # Python servers, shell scripts
└── docs/                     # This documentation
```

## Xcode Configuration

### Scheme

The `ReaderPro` scheme builds the app target and test target.

### Signing

For development: use your Apple Developer account with automatic signing.

For App Store: configure distribution certificate and provisioning profile.

### Entitlements

Required for sandboxed operation:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

## Environment Variables

| Variable | Purpose |
|---|---|
| `SOURCE_ROOT` | Helps locate model files and scripts during development |

## Common Issues

- **ONNX model not found:** Ensure `kokoro-v1.0.onnx` is in `scripts/Resources/Models/kokoro/`
- **espeak-ng not loading:** Check that `libespeak-ng.dylib` is in `ReaderPro/Resources/espeak-ng/lib/`
- **Python server won't start:** Verify Python 3.10+ and required packages are installed
- **Build fails with SPM errors:** Delete `~/Library/Developer/Xcode/DerivedData/` and rebuild
