# TTS Adapters

Adaptadores para diferentes servicios de Text-to-Speech.

## KokoroTTSAdapter

Adapter para Kokoro TTS (https://github.com/remixer-dec/kokoro-onnx), un TTS de alta calidad que se ejecuta localmente.

### Servidor HTTP

El adapter se comunica con un servidor HTTP local en Python que debe estar corriendo en `http://localhost:8880`.

### Endpoints Requeridos

```
GET  /health     → Health check (retorna 200)
POST /synthesize → Sintetiza texto a audio
```

### Request JSON para /synthesize

```json
{
  "text": "Hello world",
  "voice": "af",
  "speed": 1.0
}
```

### Response

Retorna audio WAV binario con header `Content-Type: audio/wav`.

### Voces Disponibles

| Voice ID | Nombre | Idioma |
|----------|--------|--------|
| `af` | American Female | en-US |
| `am` | American Male | en-US |
| `bf` | British Female | en-GB |
| `bm` | British Male | en-GB |
| `af_bella` | Bella (American Female) | en-US |
| `af_sarah` | Sarah (American Female) | en-US |
| `am_adam` | Adam (American Male) | en-US |
| `am_michael` | Michael (American Male) | en-US |

### Ejemplo de Servidor Python

```python
from flask import Flask, request, send_file
import kokoro_onnx  # Placeholder para librería Kokoro

app = Flask(__name__)

@app.route('/health')
def health():
    return {'status': 'ok'}, 200

@app.route('/synthesize', methods=['POST'])
def synthesize():
    data = request.json
    text = data['text']
    voice = data['voice']
    speed = data.get('speed', 1.0)

    # Generar audio usando Kokoro
    audio_data = kokoro_onnx.synthesize(text, voice=voice, speed=speed)

    # Retornar WAV
    return send_file(
        audio_data,
        mimetype='audio/wav'
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8880)
```

### Iniciar el Servidor

```bash
python kokoro_server.py
```

### Testing

El adapter incluye tests unitarios usando mocks de URLSession, por lo que no necesitas tener el servidor corriendo para ejecutar los tests.
