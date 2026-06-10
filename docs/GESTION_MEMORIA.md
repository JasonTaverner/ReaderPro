# Gestión de memoria y ciclo de vida de los modelos de IA

> Reglas de la casa para ReaderPro. Cualquier modelo o servidor nuevo (ver
> `ROADMAP_IA.md`) debe cumplir TODAS las reglas de este documento.
> Última revisión: 10-6-2026, tras corregir los procesos huérfanos que
> retenían GBs de RAM al cerrar la app.

## El presupuesto

Hardware de referencia: **Mac M4 con 16 GB de RAM unificada** (compartida entre
sistema, app y GPU/MLX). Presupuesto aproximado en uso:

| Componente | RAM | Cuándo está cargado |
|---|---|---|
| App (SwiftUI + ONNX Runtime estático) | ~200-400 MB | Siempre |
| Kokoro ONNX in-process | ~500 MB | Desde la primera síntesis Kokoro hasta cambiar de proveedor |
| Servidor Qwen3 (Python + MLX, sin modelo) | ~300-500 MB | Mientras el servidor corre |
| Modelo Qwen3-TTS 1.7B 4-bit | ~2-3 GB | Desde la primera síntesis hasta 10 min de inactividad |
| mlx-whisper (transcripción al clonar) | ~1 GB | Durante la transcripción |
| Miniaturas en memoria (ThumbnailCache) | ≤ ~30 MB | LRU, máx. 100 |

Regla de oro: **el peor caso simultáneo no debe superar ~4-5 GB**. Con 16 GB
compartidos, pasar de ahí degrada todo el sistema (swap, GPU sin memoria).

## Las 5 reglas

### 1. Un solo modelo grande cargado a la vez

`ModelManager` en `_scripts/qwen3_mlx_server.py` garantiza que cargar un modelo
descarga el anterior (`_unload_current()` + `gc.collect()` + limpieza de caché
MLX). Cualquier modelo nuevo que se añada al servidor MLX **debe registrarse a
través de ese manager**, nunca cargarse por su cuenta.

### 2. Carga perezosa, nunca al arranque

Ningún modelo se carga al arrancar la app ni al arrancar un servidor. Se carga
en la **primera petición** que lo necesita. Así el arranque es instantáneo y la
RAM solo se paga cuando se usa. (El servidor imprime "Models will load on
demand"; el engine ONNX hace `loadModel()` en el primer `synthesize`.)

### 3. Descarga por inactividad

- **Servidor Qwen3**: `--idle-timeout` (por defecto **600 s**) — un hilo daemon
  comprueba cada 30 s y descarga el modelo si no se ha usado. La siguiente
  petición lo recarga de forma transparente. `0` lo desactiva (uso manual).
- **Kokoro ONNX in-process**: `TTSServerCoordinator.switchProvider` llama a
  `engine.unloadModel()` al cambiar a un proveedor que no lo usa.
- Además, el usuario puede apagar servidores desde Ajustes (toggles) y existe
  `POST /unload` para liberar manualmente.

### 4. Ningún proceso sobrevive a la app (la regla que faltaba)

Historia: los servidores Python quedaban **huérfanos reteniendo 2-4 GB** si la
app moría sin pasar por `applicationWillTerminate` (crash, force-quit, kill).
Defensa en tres capas, de la más a la menos fiable:

1. **Watchdog padre-muerto (`--exit-with-parent`)**: la app lanza cada servidor
   con un `Pipe` conectado a su stdin (`ProcessWrapper.standardInput`). Si la
   app muere POR CUALQUIER VÍA, el kernel cierra el pipe, el servidor ve EOF en
   stdin y hace `os._exit(0)`. Cubre crash y kill -9. El pipe debe RETENERSE en
   el manager (`serverStdinPipe`) mientras viva el proceso — si se libera antes,
   el hijo muere al instante.
2. **Cierre ordenado**: `applicationShouldTerminate`/`WillTerminate` →
   `stopAllServers()` → cierre del pipe stdin + SIGTERM al **process group**
   (`kill(-pid)`, los hijos se crean como líderes de grupo con `setpgid`) +
   SIGKILL al segundo si sigue vivo.
3. **Kill por puerto al parar**: `killProcessesOnPort` (lsof) caza servidores
   arrancados externamente o huérfanos de versiones antiguas.

Si lanzas el servidor A MANO desde terminal (desarrollo), no pases
`--exit-with-parent` y no te afectará nada de esto.

### 5. Sin dobles arranques

`startServer()` reserva `status = .starting` **antes** del primer `await`
(health check). Antes había una ventana de carrera y dos llamadas concurrentes
lanzaban dos procesos (el segundo moría con "Address already in use" — ruido y
riesgo). Si la app detecta un servidor sano ya corriendo, lo **reutiliza**, no
lanza otro.

## Checklist para añadir un modelo nuevo (Fases 1-4 del ROADMAP_IA)

- [ ] Se registra en el `ModelManager` del servidor MLX (regla 1) con su
      `model_type` → `model_id`.
- [ ] No se precarga: solo en la primera petición (regla 2).
- [ ] Le aplica el idle-unload existente sin trabajo extra (regla 3) — si el
      modelo necesita otro timeout, parametrizarlo, no desactivarlo.
- [ ] Si requiere un proceso/servidor NUEVO: debe aceptar `--exit-with-parent`
      (copiar `start_parent_watchdog()` de los servers actuales), lanzarse vía
      `ProcessWrapper` con pipe a stdin, crearse como líder de process group y
      registrarse en `stopAllServers()` (regla 4).
- [ ] Documentar aquí su consumo de RAM medido (Activity Monitor, pico y
      sostenido) y actualizar la tabla del presupuesto.
- [ ] Probar el ciclo completo: generar audio → esperar idle-timeout → ver el
      log "unloading to free memory" → generar de nuevo (recarga transparente)
      → cerrar la app con force-quit → verificar con `ps aux | grep -i server`
      que no queda ningún proceso.

## Cómo verificar que no hay huérfanos (manual de 1 minuto)

```bash
# 1. Abre ReaderPro y genera un audio con Qwen3 (carga el modelo)
# 2. Fuerza el peor caso: mata la app sin piedad
pkill -9 ReaderPro
# 3. Espera 2 segundos y comprueba: no debe salir NADA
sleep 2 && ps aux | grep -E "qwen3_mlx_server|kokoro_server" | grep -v grep
```
