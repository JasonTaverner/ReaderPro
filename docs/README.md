# ReaderPro Documentation

**ReaderPro** is a native macOS application for converting text to high-quality audio, managing audio projects, and editing generated speech. Built with Swift 5.9+, SwiftUI, and designed for Apple Silicon.

## Tech Stack

| Technology | Purpose |
|---|---|
| **Swift 5.9+** | Primary language |
| **SwiftUI** | Declarative UI framework |
| **SwiftData** | Data persistence (macOS 14+) |
| **AVFoundation** | Audio playback and editing |
| **ONNX Runtime** | Local Kokoro TTS inference |
| **MLX** | Local Qwen3-TTS inference (Python server) |
| **Vision** | OCR text recognition |
| **PDFKit** | PDF parsing and generation |

## System Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4) recommended for local TTS
- Xcode 15+ for building
- Python 3.10+ for Qwen3-TTS server
- ~2GB disk for Kokoro ONNX model
- ~4GB disk for Qwen3 models

## Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd ReaderPro

# Open in Xcode
open ReaderPro.xcodeproj

# Build and run (Cmd+R)
# The app will create ~/Documents/KokoroLibrary/ on first launch

# (Optional) Start Qwen3 TTS server
pip install mlx-audio flask soundfile numpy
python scripts/qwen3_mlx_server.py
```

## Documentation Index

### Architecture
- [Architecture Overview](architecture/OVERVIEW.md) - DDD + Hexagonal Architecture
- [Domain Layer](architecture/DOMAIN_LAYER.md) - Entities, Value Objects, Aggregates
- [Application Layer](architecture/APPLICATION_LAYER.md) - Use Cases, DTOs, Ports
- [Infrastructure Layer](architecture/INFRASTRUCTURE_LAYER.md) - Adapters, Repositories
- [UI Layer](architecture/UI_LAYER.md) - Views, ViewModels, Presenters

### Features
- [TTS: Kokoro ONNX](features/TTS_KOKORO.md) - Local ONNX-based TTS (82M params)
- [TTS: Qwen3](features/TTS_QWEN3.md) - MLX-based TTS (CustomVoice, VoiceDesign, Cloning)
- [OCR & Screen Capture](features/OCR.md) - Image-to-text processing
- [Project Management](features/PROJECT_MANAGEMENT.md) - File storage and project lifecycle
- [Audio Playback](features/AUDIO_PLAYBACK.md) - Player controls and auto-play
- [Voice Customization](features/VOICE_CUSTOMIZATION.md) - Accents, emotions, cloning

### Diagrams
- [Data Flow](diagrams/data_flow.mermaid) - TTS synthesis pipeline
- [Project Structure](diagrams/project_structure.mermaid) - File system layout
- [Class Diagram](diagrams/class_diagram.mermaid) - Core domain classes

### Development
- [Dev Setup](development/SETUP.md) - Environment configuration
- [Testing Guide](development/TESTING.md) - Running and writing tests
- [Adding Features](development/ADDING_FEATURES.md) - Step-by-step guide
- [Coding Standards](development/CODING_STANDARDS.md) - Conventions and naming

### Reference
- [Architecture Decision](ARCHITECTURE.md) - Why DDD + Hexagonal
- [Getting Started](GETTING_STARTED.md) - First-time setup walkthrough
- [User Guide](USER_GUIDE.md) - End-user manual
- [API Reference](API_REFERENCE.md) - Internal API documentation
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

## Ver documentación en web local

La documentación se puede visualizar como una web local con navegación, búsqueda y renderizado de diagramas Mermaid.

```bash
# 1. Abre terminal en la carpeta del proyecto
cd ReaderPro

# 2. Ejecuta el servidor local
python docs/website/serve.py

# 3. Se abrirá automáticamente en http://localhost:8000/website/
```

**Características:**
- Navegación con sidebar y búsqueda instantánea
- Renderizado de Markdown con syntax highlighting (Swift, Python, Bash, JSON)
- Diagramas Mermaid interactivos
- Modo oscuro/claro con persistencia
- Botón de copiar en bloques de código
- Tabla de contenidos (TOC) por página
- Diseño responsive (desktop + móvil)
