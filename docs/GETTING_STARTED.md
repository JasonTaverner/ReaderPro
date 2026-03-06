# Getting Started

First-time setup walkthrough for ReaderPro development.

## 1. Clone the Repository

```bash
git clone <repo-url>
cd ReaderPro
```

## 2. Open in Xcode

```bash
open ReaderPro.xcodeproj
```

Xcode will automatically resolve SPM dependencies (ONNX Runtime).

## 3. Build and Run

**Cmd+R** to build and run. The app creates `~/Documents/ReaderProLibrary/` on first launch.

## 4. Set Up TTS (Optional)

### Option A: Kokoro ONNX (Local, No Server)

This is the default if model files are in place:

```
scripts/Resources/Models/kokoro/
├── kokoro-v1.0.onnx
└── voices-v1.0.bin
```

And espeak-ng resources in:
```
ReaderPro/Resources/espeak-ng/
├── lib/libespeak-ng.dylib
└── share/espeak-ng-data/
```

### Option B: Kokoro Server

```bash
pip install kokoro-onnx flask soundfile numpy
python scripts/kokoro_server.py
```

### Option C: Qwen3-TTS

```bash
pip install mlx-audio flask soundfile numpy
python scripts/qwen3_mlx_server.py
```

Models download automatically on first use.

## 5. Create Your First Project

1. Launch the app
2. Click **"+"** in the toolbar to create a new project
3. Enter a project name
4. Add text content in the editor
5. Select a voice from the sidebar
6. Click **"Generate Audio"**
7. Use the player controls to listen

## 6. Run Tests

**Cmd+U** in Xcode, or:

```bash
xcodebuild -scheme ReaderPro -configuration Debug test
```

## 7. Explore the Codebase

Start here to understand the architecture:

| Path | What's There |
|---|---|
| `ReaderPro/Domain/` | Business logic, no dependencies |
| `ReaderPro/Application/` | Use cases orchestrating domain |
| `ReaderPro/Infrastructure/` | Adapters (TTS, persistence, OCR) |
| `ReaderPro/UI/` | SwiftUI views and presenters |
| `ReaderPro/App/DependencyContainer.swift` | All wiring |
| `ReaderPro/Tests/` | Test suite (879+ tests) |

## 8. Key Files to Read First

1. **`DependencyContainer.swift`** — How everything connects
2. **`TTSPort.swift`** — The TTS interface contract
3. **`Project.swift`** — The aggregate root
4. **`EditorPresenter.swift`** — The main presenter
5. **`ProjectDetailView.swift`** — The main editing view

## Next Steps

- Read the [Architecture Overview](architecture/OVERVIEW.md)
- See [Adding Features](development/ADDING_FEATURES.md) for contributing
- Check [Coding Standards](development/CODING_STANDARDS.md) for conventions
