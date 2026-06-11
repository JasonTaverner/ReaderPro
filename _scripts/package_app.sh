#!/bin/bash
# Empaqueta ReaderPro para distribución: build Release + ZIP con instalador.
#
# Uso: ./_scripts/package_app.sh [--no-servers]
#   --no-servers  No incluye el servidor MLX empaquetado (ZIP ligero ~20 MB;
#                 Qwen3/VoxCPM/Chatterbox/Supertonic requerirán Python).
#
# Salida: dist/ReaderPro-<versión>.zip
#         Con el servidor incluido la app no necesita Python para NINGÚN motor;
#         los modelos de voz se descargan automáticamente al primer uso.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

INCLUDE_SERVERS=1
[ "${1:-}" = "--no-servers" ] && INCLUDE_SERVERS=0

VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
BUILD_DIR="$REPO_ROOT/build/DerivedData"
APP="$BUILD_DIR/Build/Products/Release/ReaderPro.app"
DIST="$REPO_ROOT/dist"
STAGING="$DIST/ReaderPro"

echo "==> Regenerando proyecto (xcodegen)"
xcodegen generate

echo "==> Compilando Release"
xcodebuild -project ReaderPro.xcodeproj -scheme ReaderPro -configuration Release \
    -derivedDataPath "$BUILD_DIR" build CODE_SIGN_IDENTITY="-" -quiet

echo "==> Verificando bundle"
test -f "$APP/Contents/Resources/espeak-ng/libespeak-ng.dylib" || { echo "ERROR: falta libespeak-ng.dylib"; exit 1; }
test -d "$APP/Contents/Resources/espeak-ng/espeak-ng-data" || { echo "ERROR: falta espeak-ng-data"; exit 1; }
if find "$APP" -name "*.onnx" | grep -q .; then
    echo "AVISO: hay un modelo .onnx dentro del bundle (engordará el ZIP innecesariamente)"
fi

if [ "$INCLUDE_SERVERS" = "1" ]; then
    SERVER_DIST="$REPO_ROOT/_scripts/pyinstaller/dist/qwen3_server"
    if [ ! -x "$SERVER_DIST/qwen3_server" ]; then
        echo "==> Servidor MLX no construido; ejecutando PyInstaller"
        "$REPO_ROOT/_scripts/pyinstaller/build_qwen3_server.sh"
    fi
    echo "==> Incluyendo servidor MLX empaquetado ($(du -sh "$SERVER_DIST" | cut -f1))"
    mkdir -p "$APP/Contents/Resources/servers"
    rm -rf "$APP/Contents/Resources/servers/qwen3_server"
    cp -R "$SERVER_DIST" "$APP/Contents/Resources/servers/qwen3_server"
    test -x "$APP/Contents/Resources/servers/qwen3_server/qwen3_server" \
        || { echo "ERROR: el ejecutable qwen3_server no quedó en el bundle"; exit 1; }
fi

echo "==> Firmando (adhoc)"
codesign --force --deep --sign - "$APP"

echo "==> Preparando paquete"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"

cat > "$STAGING/INSTALL.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Instalando ReaderPro..."
xattr -cr ReaderPro.app
cp -R ReaderPro.app /Applications/
open /Applications/ReaderPro.app
echo "Instalado en /Applications"
EOF
chmod +x "$STAGING/INSTALL.command"

cat > "$STAGING/LEEME.txt" <<'EOF'
ReaderPro
=========

Instalación:
1. Doble clic en INSTALL.command
   (si macOS lo bloquea: clic derecho > Abrir, o ejecuta en Terminal:
    xattr -cr ReaderPro.app && cp -R ReaderPro.app /Applications/)
2. Abre ReaderPro desde Aplicaciones.

Primer arranque:
- La app descarga automáticamente el modelo de voz Kokoro (~350 MB, solo
  una vez). Puedes ver el progreso en Ajustes (⌘,) > sección Kokoro.
- Mientras descarga, puedes usar las voces del sistema (System/macOS).

Voces premium (Qwen3, VoxCPM2, Chatterbox, Supertonic):
- Incluidas: no necesitas instalar Python ni nada más. La primera vez
  que uses cada motor, la app descarga su modelo (0,4-3 GB según el
  motor, solo una vez).

Código fuente (GPLv3): este programa es software libre.
EOF

echo "==> Creando ZIP"
mkdir -p "$DIST"
ZIP="$DIST/ReaderPro-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGING" "$ZIP"
rm -rf "$STAGING"

echo
echo "Paquete listo: $ZIP ($(du -h "$ZIP" | cut -f1 | xargs))"
echo "Pásalo a quien quieras: descomprimir y doble clic en INSTALL.command."
