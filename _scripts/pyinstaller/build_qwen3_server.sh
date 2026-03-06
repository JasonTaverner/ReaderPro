#!/bin/bash
# Build Qwen3 MLX server as standalone executable using PyInstaller.
# Output: scripts/pyinstaller/dist/qwen3_server/ (onedir bundle)
#
# Usage:
#   cd scripts/pyinstaller && ./build_qwen3_server.sh
#
# The resulting directory can be copied into the .app bundle at:
#   ReaderPro.app/Contents/Resources/servers/qwen3_server/
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_SCRIPT="$PROJECT_DIR/qwen3_mlx_server.py"

if [ ! -f "$SERVER_SCRIPT" ]; then
    echo "Error: $SERVER_SCRIPT not found"
    exit 1
fi

# Ensure PyInstaller is installed
if ! python3 -m PyInstaller --version &>/dev/null; then
    echo "PyInstaller not found, installing..."
    pip3 install pyinstaller
fi

echo "Building Qwen3 MLX server standalone executable..."
echo "Source: $SERVER_SCRIPT"

python3 -m PyInstaller \
    --name qwen3_server \
    --distpath "$SCRIPT_DIR/dist" \
    --workpath "$SCRIPT_DIR/build" \
    --specpath "$SCRIPT_DIR" \
    --noconfirm \
    --hidden-import=mlx \
    --hidden-import=mlx.core \
    --hidden-import=mlx.nn \
    --hidden-import=mlx_audio \
    --hidden-import=mlx_audio.tts \
    --hidden-import=mlx_audio.tts.generate \
    --hidden-import=soundfile \
    --hidden-import=numpy \
    --hidden-import=flask \
    --hidden-import=huggingface_hub \
    --hidden-import=transformers \
    --hidden-import=safetensors \
    --collect-all mlx \
    --collect-all mlx_audio \
    "$SERVER_SCRIPT"

echo ""
echo "Build complete: $SCRIPT_DIR/dist/qwen3_server/"
echo ""
echo "To test:"
echo "  $SCRIPT_DIR/dist/qwen3_server/qwen3_server --port 8890"
echo "  curl http://localhost:8890/health"
echo ""
echo "To bundle in app:"
echo "  cp -R $SCRIPT_DIR/dist/qwen3_server/ ReaderPro.app/Contents/Resources/servers/qwen3_server/"
