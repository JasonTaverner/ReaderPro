# Roadmap de modelos de IA (TTS) — ReaderPro

> Objetivo: ampliar los motores de voz de ReaderPro en Macs Apple Silicon con 16 GB
> (referencia: M4 16 GB). Investigación de modelos verificada a junio de 2026.
> Regla de oro: con 16 GB de RAM unificada solo se carga UN modelo grande a la vez
> (el `ModelManager` del servidor MLX ya lo garantiza).

## Estado actual

| Motor | Vía | Tamaño | Papel |
|---|---|---|---|
| Kokoro-82M | ONNX in-process (sin Python) | ~350 MB (descarga automática) | Rápido, 26+ voces, 10 idiomas — ojo: sus voces "es" son acento LatAm |
| Qwen3-TTS 1.7B/0.6B 4-bit | Servidor MLX Python (`_scripts/qwen3_mlx_server.py`) | 1–2,2 GB | Premium: clonación, emociones, acentos, VoiceDesign |
| macOS nativo (AVSpeech) | In-process | 0 | Fallback sin descargas |

Criterios para añadir un modelo:
1. **Español es-ES de calidad** (criterio nº 1).
2. **Cabe holgado en 16 GB**: ≤4–5 GB en disco/RAM, cuantizado 4–8 bit.
3. **Licencia redistribuible** (Apache-2.0/MIT) para una app GPLv3 gratuita.
4. **Integrable vía mlx-audio** (la dependencia que ya usa el servidor Qwen3) u ONNX.
5. Validación A/B en español con textos propios antes de exponerlo en la UI.

---

> **Regla transversal**: todo modelo o servidor nuevo debe cumplir las reglas de
> [`docs/GESTION_MEMORIA.md`](docs/GESTION_MEMORIA.md) (un modelo a la vez, carga
> perezosa, descarga por inactividad, ningún proceso sobrevive a la app).

## Fase 0 — Correcciones y base (en curso)

- [x] Fix espeak-ng: pasar el directorio padre de `espeak-ng-data` a `espeak_Initialize`
      + flag `DONT_EXIT` (10-6-2026).
- [x] Empaquetado autocontenido + descarga automática de modelos Kokoro
      (`KokoroModelStore`, `_scripts/package_app.sh`) (10-6-2026).
- [ ] Probar síntesis Kokoro end-to-end desde la app (generar audio de una entrada en español).
- [x] **Generalizar el servidor MLX** (10-6-2026): `MODEL_REGISTRY` declarativo en
      `qwen3_mlx_server.py` (se mantuvo el nombre del fichero por compatibilidad con
      las rutas de búsqueda del manager Swift), `/models` dinámico, `/synthesize`
      acepta `mode=voxcpm` y `/clone` acepta `model=base|base_fast|voxcpm`.
      Añadir un modelo nuevo = una entrada en el diccionario (+ rama de kwargs si
      su familia los necesita). mlx-audio actualizado 0.3.1 → 0.4.4 (verificado
      que la clonación Qwen3 sigue funcionando).

## Fase 1 — VoxCPM2: el más potente con el mejor español viable

**El upgrade principal de calidad.** OpenBMB VoxCPM2 (abril 2026).

- **Modelo**: `mlx-community/VoxCPM2-8bit` (~2,5–3 GB en 8-bit; existe 4-bit si hace falta velocidad).
- **Por qué**: Apache-2.0; español excelente (WER 1,44 %, 30 idiomas); salida **48 kHz**
  (Kokoro y Qwen3 van a 24 kHz — diferencia audible en lectura larga); clonación de voz
  y diseño de voz por descripción; **soporte oficial en mlx-audio** → integración casi trivial.
- **Benchmark REAL en el M4 16 GB (10-6-2026)**: carga 3,3 s; salida 48 kHz ✓;
  **RTF 0,36–0,49× — más lento que tiempo real**. La variante 4-bit NO acelera
  (RTF 0,45-0,49, el cuello es el módulo de difusión) → usar la 8-bit.
  **Decisión**: VoxCPM2 no vale como voz interactiva por defecto en M4 base;
  posicionarlo como "máxima calidad para generación en lote/exportación de
  audiolibros" (ReaderPro pre-genera el audio, así que la espera 2× es asumible).
  Pendiente: valorar el español escuchando /tmp/voxcpm_test/*.wav.
- **Estado (10-6-2026, tarde): PROVEEDOR DE PRIMERA CLASE.** VoxCPM2 aparece junto a
  Kokoro/Qwen3 en los selectores de proveedor (proyecto y Ajustes) con panel propio:
  instrucciones de estilo en texto libre (p. ej. "Habla pausadamente" — remedio al
  ritmo acelerado que notó el usuario), estabilidad de voz (cfg 1.0-3.0), calidad de
  difusión (5-30 pasos) y clonación con perfiles guardados (sin opciones Qwen).
  `VoxCPMTTSAdapter` nuevo; comparte servidor MLX y gestión de memoria con Qwen3.
  Nota: el modelo ignora `speed` en generación; la velocidad se ajusta en reproducción.
- Integración previa (mañana): Registro en el servidor ✓, benchmark ✓, español
  validado por el usuario ("me gusta mucho el resultado") ✓, clonación end-to-end vía
  `/clone` con `model=voxcpm` verificada (48 kHz) sin regresión del camino Qwen3 ✓,
  y UI: toggle **"Maximum quality (VoxCPM2, 48 kHz)"** en la sección de clonación
  (persistido en UserDefaults, deshabilita los toggles de velocidad).
  Pendiente menor: probar con sus perfiles clonados reales y textos largos.
- Fuentes: github.com/OpenBMB/VoxCPM · huggingface.co/mlx-community/VoxCPM2-8bit

## Fase 2 — MOSS-TTS-Local 1.7B: el de los textos más largos

**La killer feature para una app de lectura**: genera hasta **1 hora de audio en una sola
pasada** con prosodia coherente — ningún otro lo hace; todos los demás obligan a trocear
y la prosodia "se reinicia" en cada fragmento.

- **Modelo**: `OpenMOSS-Team/MOSS-TTS` (v1.5, feb 2026), variantes 4/8-bit en mlx-community
  (~1–1,8 GB). Apache-2.0. Clonación zero-shot. 20–31 idiomas.
- **Riesgo a validar**: el español no tiene benchmark específico (es 1 de 20+ idiomas):
  hacer A/B contra Qwen3-TTS antes de invertir en UI.
- **Tareas**: registro en servidor MLX → **ruta de "generación larga"** en la app que
  salte el troceo (hoy las entradas van limitadas a ~6.000 caracteres: para este modelo,
  permitir capítulo completo → un único WAV) → A/B español.
- **Esfuerzo**: 2–4 días (la ruta long-form es la parte nueva de verdad).
  Fuentes: huggingface.co/OpenMOSS-Team/MOSS-TTS · github.com/Blaizzy/mlx-audio-swift

## Fase 3 — Chatterbox Multilingual 500M: el equilibrio ligero (MIT)

- **Modelo**: ResembleAI Chatterbox Multilingual vía mlx-audio (~1–1,5 GB). **MIT** puro.
- **Por qué**: español valorado como excelente en pruebas de terceros; clonación zero-shot;
  control de exageración/emoción; la mitad de RAM que Qwen3 1.7B y más rápido que VoxCPM2.
  Es el plan B perfecto si VoxCPM2 resulta lento en M4 base, y el motor recomendable
  para Macs de 8 GB si algún día se soportan.
- **Nota**: incrusta watermark Perth en el audio (inocuo; documentarlo).
- **Esfuerzo**: 1–2 días. Fuente: github.com/resemble-ai/chatterbox

## Fase 4 (opcional) — Supertonic v3: tier ultrarrápido 100 % nativo

- **Modelo**: Supertone Supertonic v3 — **ONNX, 404 MB**, mismo stack que Kokoro
  (sin Python), 31 idiomas, decenas de veces tiempo real, tags de expresión y
  normalización de fechas/cifras superior (útil en documentos).
- **Papel**: candidato a sustituir a Kokoro como motor por defecto **si** sus 10 voces
  preset suenan nativas en español (verificar — son voces compartidas entre idiomas).
- **Ojo licencia**: código MIT pero pesos **OpenRAIL-M** (redistribuible con restricciones
  de uso): descargarlo bajo demanda con aviso, como Kokoro, y revisar la licencia antes.
- **Esfuerzo**: 3–5 días (integración ONNX propia: tokenizado/normalización distintos).
  Fuente: github.com/supertone-inc/supertonic

## Mejoras transversales (durante cualquier fase)

- Selector de modelo en Ajustes con RAM y velocidad esperadas por modelo.
- Progreso de descarga de modelos MLX visible en la app (el endpoint `/progress` ya existe).
- `Qwen3-TTS-0.6B` como default de la familia Qwen (más rápido, poca pérdida).
- Benchmark integrado al elegir motor por primera vez ("tu Mac genera a N× tiempo real").

## Qué NO añadir (descartados con motivo)

| Modelo | Por qué no |
|---|---|
| **Voxtral TTS 4B** (Mistral) | El MEJOR español del mercado abierto (87,8 % preferencia vs ElevenLabs), pero **CC-BY-NC**: no redistribuible con la app. Como mucho, documentar cómo instalarlo por cuenta del usuario |
| Fish Audio S2 Pro | Licencia research/no comercial + 5,3 GB (asfixia 16 GB) + español Tier 2 |
| Higgs Audio v3, IndexTTS-2.5, F5-TTS | Pesos con licencias no comerciales |
| KugelAudio-0-open 7B | MIT y buen español, pero 9 GB sin cuantización documentada: no cabe. Candidato futuro para Macs 32 GB+ |
| Dia, CSM-1B, Marvis, Kyutai, Zonos, VibeVoice, OuteTTS, Maya1 | Sin español (o abandonados) |
| MeloTTS, Piper | Calidad inferior a Kokoro: sería retroceder |

## Orden recomendado y criterio de éxito

1. **Fase 0 completa** (sin base multi-modelo, cada fase duplica trabajo).
2. **Fase 1 (VoxCPM2)** — si pasa el benchmark de velocidad, se convierte en la voz premium por defecto.
3. **Fase 2 (MOSS-TTS)** — si pasa el A/B de español, habilita el modo "capítulo entero de una pasada".
4. **Fase 3 (Chatterbox)** — sobre todo si VoxCPM2 decepciona en velocidad.
5. **Fase 4 (Supertonic)** — solo si el A/B de voces españolas convence.

Criterio de éxito por modelo: RTF ≥ 1 en M4 16 GB con la app abierta + mejor que el motor
actual equivalente en una prueba ciega con 3 textos en español (narrativa, técnico, números/fechas).
