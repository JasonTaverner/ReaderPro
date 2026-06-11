#!/bin/bash
# Build del servidor MLX (Qwen3/VoxCPM2/Chatterbox/Supertonic + /transcribe Whisper)
# como ejecutable autocontenido con PyInstaller (sin Python en la máquina destino).
#
# Salida: _scripts/pyinstaller/dist/qwen3_server/ (bundle onedir)
#
# Uso:
#   ./_scripts/pyinstaller/build_qwen3_server.sh
#
# package_app.sh lo copia dentro del .app en:
#   ReaderPro.app/Contents/Resources/servers/qwen3_server/
#
# Notas:
# - torch/torchaudio se EXCLUYEN a propósito: mlx-audio solo los usa como
#   fallback para pesos .pth y los modelos mlx-community traen safetensors.
#   Sin esa exclusión el bundle pasa de ~0,8 GB a ~3 GB.
# - Los modelos NO van en el bundle: se descargan bajo demanda a
#   ~/.cache/huggingface (mlx-audio) y al cache propio de supertonic.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_SCRIPT="$SCRIPTS_DIR/qwen3_mlx_server.py"

if [ ! -f "$SERVER_SCRIPT" ]; then
    echo "Error: $SERVER_SCRIPT not found"
    exit 1
fi

if ! python3 -m PyInstaller --version &>/dev/null; then
    echo "PyInstaller not found, installing..."
    pip3 install pyinstaller
fi

echo "==> Building MLX TTS server standalone executable..."
echo "    Source: $SERVER_SCRIPT"
echo "    Python: $(python3 --version) ($(which python3))"

python3 -m PyInstaller \
    --name qwen3_server \
    --distpath "$SCRIPT_DIR/dist" \
    --workpath "$SCRIPT_DIR/build" \
    --specpath "$SCRIPT_DIR" \
    --noconfirm \
    --onedir \
    --collect-all mlx \
    --collect-all mlx_audio \
    --collect-all mlx_whisper \
    --collect-all supertonic \
    --collect-all misaki \
    --hidden-import=scipy.signal \
    --hidden-import=psutil \
    --hidden-import=soundfile \
    --hidden-import=flask \
    --exclude-module torch \
    --exclude-module torchaudio \
    --exclude-module torchvision \
    --exclude-module pytorch_lightning \
    --exclude-module torchmetrics \
    --exclude-module kokoro_onnx \
    --exclude-module matplotlib \
    --exclude-module gradio \
    --exclude-module IPython \
    --exclude-module pytest \
    "$SERVER_SCRIPT"

BUNDLE="$SCRIPT_DIR/dist/qwen3_server"
echo ""
echo "==> Build complete: $BUNDLE ($(du -sh "$BUNDLE" | cut -f1))"
echo ""
echo "Smoke test:"
echo "  $BUNDLE/qwen3_server --port 8899"
echo "  curl http://localhost:8899/health"
