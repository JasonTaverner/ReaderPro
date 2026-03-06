#!/usr/bin/env python3
"""
Qwen3-TTS MLX Server for ReaderPro

A lightweight HTTP server that provides Text-to-Speech synthesis using
Qwen3-TTS via MLX on Apple Silicon. Supports 9 premium voices, emotion
control via instruct, voice cloning from reference audio, and VoiceDesign
mode for languages without a native speaker voice.

Models:
    CustomVoice: mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit (~1GB)
    VoiceDesign: mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit (~1GB)
    Base:        mlx-community/Qwen3-TTS-12Hz-1.7B-Base-4bit (~1GB) - for voice cloning
    Base Fast:   mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit - lightweight cloning

Endpoints:
    GET  /health      - Health check
    GET  /voices      - List available voices
    GET  /models      - List loaded/available models
    GET  /progress    - Poll generation progress
    POST /synthesize  - Convert text to speech with speaker + instruct or voice_design
    POST /clone       - Voice cloning from reference audio (multipart/form-data)
    POST /cancel      - Cancel in-progress generation
    POST /transcribe  - Transcribe audio to text using mlx-whisper

Usage:
    python qwen3_mlx_server.py [--port PORT] [--host HOST]

Requirements:
    pip install mlx-audio flask soundfile numpy mlx-whisper

Author: ReaderPro Team
"""

import argparse
import hashlib
import io
import logging
import os
import platform
import sys
import tempfile
import threading
import time

import mlx.core as mx
import numpy as np
import soundfile as sf
from flask import Flask, Response, jsonify, request

# Force MLX to use GPU (Metal) on Apple Silicon
mx.set_default_device(mx.gpu)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Default configuration
DEFAULT_SAMPLE_RATE = 24000
DEFAULT_SPEED = 1.0
CUSTOM_VOICE_MODEL_ID = "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit"
VOICE_DESIGN_MODEL_ID = "mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit"
BASE_MODEL_ID = "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-4bit"
BASE_MODEL_FAST_ID = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit"

# Keep backward-compatible alias
MODEL_ID = CUSTOM_VOICE_MODEL_ID

# Model type constants
MODEL_TYPE_CUSTOM_VOICE = "custom_voice"
MODEL_TYPE_VOICE_DESIGN = "voice_design"
MODEL_TYPE_BASE = "base"
MODEL_TYPE_BASE_FAST = "base_fast"

# Maps model type to HuggingFace model ID
MODEL_TYPE_TO_ID = {
    MODEL_TYPE_CUSTOM_VOICE: CUSTOM_VOICE_MODEL_ID,
    MODEL_TYPE_VOICE_DESIGN: VOICE_DESIGN_MODEL_ID,
    MODEL_TYPE_BASE: BASE_MODEL_ID,
    MODEL_TYPE_BASE_FAST: BASE_MODEL_FAST_ID,
}


class ModelManager:
    """
    Manages a single TTS model at a time to avoid excessive memory usage.

    Only one model is loaded at any time. When a different model is requested,
    the current one is unloaded first (freeing ~3-6GB of RAM).
    """

    def __init__(self):
        self._current_model = None
        self._current_type: str | None = None
        self._load_count = 0

    @property
    def current_type(self) -> str | None:
        return self._current_type

    @property
    def is_loaded(self) -> bool:
        return self._current_model is not None

    def get_model(self, model_type: str):
        """
        Get the model for the given type, loading it if necessary.

        If a different model is currently loaded, it will be unloaded first
        to free memory before loading the new one.
        """
        if self._current_type == model_type and self._current_model is not None:
            return self._current_model

        # Unload current model to free memory
        if self._current_model is not None:
            self._unload_current()

        # Load the requested model
        model_id = MODEL_TYPE_TO_ID.get(model_type)
        if not model_id:
            raise ValueError(f"Unknown model type: {model_type}")

        try:
            from mlx_audio.tts.generate import load_model

            logger.info(f"Loading {model_type} model: {model_id}")
            start_time = time.time()

            self._current_model = load_model(model_id)
            self._current_type = model_type
            self._load_count += 1

            elapsed = time.time() - start_time
            logger.info(f"{model_type} model loaded in {elapsed:.2f}s")

        except ImportError as e:
            logger.error(f"Failed to import mlx-audio: {e}")
            logger.error("Install with: pip install mlx-audio")
            raise
        except Exception as e:
            logger.error(f"Failed to load {model_type} model: {e}")
            raise

        return self._current_model

    def unload(self):
        """Unload the current model and free all memory."""
        if self._current_model is not None:
            self._unload_current()
            return True
        return False

    def _unload_current(self):
        """Internal: unload current model and aggressively free memory."""
        model_type = self._current_type
        logger.info(f"Unloading {model_type} model to free memory...")

        del self._current_model
        self._current_model = None
        self._current_type = None

        # Aggressively free memory
        import gc
        gc.collect()

        try:
            import mlx.core as mx
            mx.metal.clear_cache()
            logger.info(f"{model_type} model unloaded, Metal cache cleared")
        except Exception:
            logger.info(f"{model_type} model unloaded")

    def status(self) -> dict:
        """Return current model status for the /models endpoint."""
        return {
            "loaded_model": self._current_type,
            "loaded_model_id": MODEL_TYPE_TO_ID.get(self._current_type, None) if self._current_type else None,
            "load_count": self._load_count,
        }


# Single global model manager (replaces 3 separate global variables)
_model_manager = ModelManager()


class ProgressTracker:
    """Thread-safe tracker for generation progress, polled by the Swift client."""

    def __init__(self):
        self._lock = threading.Lock()
        self._active = False
        self._mode = ""
        self._segments_done = 0
        self._segments_total = 0
        self._current_message = ""
        self._detail_message = ""
        self._start_time = 0.0
        self._cancelled = False

    def start(self, total_segments: int, mode: str):
        with self._lock:
            self._active = True
            self._cancelled = False
            self._mode = mode
            self._segments_done = 0
            self._segments_total = total_segments
            self._current_message = f"Starting {mode} generation..."
            self._detail_message = ""
            self._start_time = time.time()

    def update(self, segments_done: int, message: str):
        with self._lock:
            self._segments_done = segments_done
            self._current_message = message

    def update_detail(self, detail: str):
        """Update the detail message (token-level progress from tqdm)."""
        with self._lock:
            self._detail_message = detail

    def cancel(self):
        with self._lock:
            self._cancelled = True
            self._current_message = "Cancelling..."

    @property
    def is_cancelled(self) -> bool:
        with self._lock:
            return self._cancelled

    def finish(self):
        with self._lock:
            self._segments_done = self._segments_total
            self._current_message = "Cancelled" if self._cancelled else "Done"
            self._detail_message = ""
            self._active = False
            self._cancelled = False

    def get_state(self) -> dict:
        with self._lock:
            elapsed = time.time() - self._start_time if self._start_time > 0 else 0
            return {
                "active": self._active,
                "cancelled": self._cancelled,
                "mode": self._mode,
                "segments_done": self._segments_done,
                "segments_total": self._segments_total,
                "current_message": self._current_message,
                "detail_message": self._detail_message,
                "elapsed": round(elapsed, 1),
            }


class TqdmCapture:
    """Captures tqdm stderr output and updates the progress tracker detail."""

    def __init__(self, progress_tracker, original_stderr):
        self._progress = progress_tracker
        self._original = original_stderr
        self._buffer = ""

    def write(self, s):
        self._original.write(s)
        # tqdm uses \r to update lines in-place; accumulate and parse
        self._buffer += s
        # Extract the latest meaningful line (tqdm uses \r separators)
        parts = self._buffer.replace("\r", "\n").split("\n")
        for part in reversed(parts):
            stripped = part.strip()
            if stripped and ("%" in stripped or "tokens/s" in stripped or "token/s" in stripped):
                self._progress.update_detail(stripped)
                break
        # Keep only the last chunk to avoid unbounded growth
        if len(self._buffer) > 4096:
            self._buffer = self._buffer[-2048:]
        return len(s)

    def flush(self):
        self._original.flush()

    def fileno(self):
        return self._original.fileno()

    def isatty(self):
        return False


_progress = ProgressTracker()


# Premium voices available in the CustomVoice model
VOICES = {
    "Vivian": {"name": "Vivian", "language": "multi", "gender": "female", "style": "warm"},
    "Serena": {"name": "Serena", "language": "multi", "gender": "female", "style": "calm"},
    "Uncle_Fu": {"name": "Uncle Fu", "language": "multi", "gender": "male", "style": "deep"},
    "Dylan": {"name": "Dylan", "language": "multi", "gender": "male", "style": "young"},
    "Eric": {"name": "Eric", "language": "multi", "gender": "male", "style": "neutral"},
    "Ryan": {"name": "Ryan", "language": "multi", "gender": "male", "style": "energetic"},
    "Aiden": {"name": "Aiden", "language": "multi", "gender": "male", "style": "friendly"},
    "Ono_Anna": {"name": "Ono Anna", "language": "multi", "gender": "female", "style": "bright"},
    "Sohee": {"name": "Sohee", "language": "multi", "gender": "female", "style": "soft"},
}

# Language codes supported
SUPPORTED_LANGUAGES = ["auto", "en", "es", "zh", "ja", "ko", "fr", "de", "it", "pt", "ru"]


def get_custom_voice_model():
    """Get the CustomVoice model (loads if needed, unloads other models)."""
    return _model_manager.get_model(MODEL_TYPE_CUSTOM_VOICE)


def get_voice_design_model():
    """Get the VoiceDesign model (loads if needed, unloads other models)."""
    return _model_manager.get_model(MODEL_TYPE_VOICE_DESIGN)


def get_base_model():
    """Get the Base model for voice cloning (loads if needed, unloads other models)."""
    return _model_manager.get_model(MODEL_TYPE_BASE)


def get_model():
    """Backward-compatible alias for get_custom_voice_model."""
    return get_custom_voice_model()


def synthesize_speech(
    text: str,
    speaker: str = "Vivian",
    language: str = "auto",
    instruct: str | None = None,
    speed: float = 1.0,
    mode: str = "custom_voice",
) -> bytes:
    """
    Synthesize speech from text using Qwen3-TTS via MLX.

    Args:
        text: Text to synthesize
        speaker: Speaker name (one of the 9 premium voices) - used in custom_voice mode
        language: Language code or "auto"
        instruct: Style/emotion instruction (custom_voice) or complete voice description (voice_design)
        speed: Speech speed multiplier (0.5 - 2.0)
        mode: "custom_voice" (default) or "voice_design"

    Returns:
        WAV audio data as bytes (24kHz, 16-bit PCM, mono)
    """
    from mlx_audio.tts.generate import generate_audio

    # Clamp speed
    speed = max(0.5, min(2.0, speed))

    # Map language for mlx-audio (use lang_code parameter)
    lang = _map_language(language)

    _progress.start(1, mode)

    try:
        if mode == "voice_design":
            # VoiceDesign mode: instruct is REQUIRED and describes the voice completely
            # No speaker needed - the model generates a voice from the description
            logger.info(f"[DIAG] VoiceDesign request: mode={mode}, lang={lang}, speed={speed}")
            logger.info(f"[DIAG] VoiceDesign instruct: {instruct!r}")
            logger.info(f"[DIAG] VoiceDesign text ({len(text)} chars): {text[:80]!r}...")

            model = get_voice_design_model()

            if not instruct:
                raise ValueError("VoiceDesign mode requires 'instruct' field with voice description")

            logger.info(f"[DIAG] Calling generate_audio(VoiceDesign): lang_code={lang}, instruct={instruct!r}")
            start_time = time.time()

            with tempfile.TemporaryDirectory() as tmpdir:
                _capture = TqdmCapture(_progress, sys.stderr)
                sys.stderr = _capture
                try:
                    generate_audio(
                        text=text,
                        model=model,
                        lang_code=lang,
                        instruct=instruct,
                        speed=speed,
                        output_path=tmpdir,
                        file_prefix="speech",
                        audio_format="wav",
                        verbose=True,
                        play=False,
                        join_audio=True,
                    )
                finally:
                    sys.stderr = _capture._original

                wav_data = _read_wav_from_dir(tmpdir, "speech")
        else:
            # CustomVoice mode: speaker is required, instruct is optional (emotion/style)
            model = get_custom_voice_model()

            # Validate speaker (case-insensitive lookup)
            voice_key = _resolve_voice_key(speaker)
            # mlx-audio expects voice names to match the model's metadata
            voice_name = voice_key

            logger.info(
                f"Synthesizing (CustomVoice): voice={voice_name}, lang={lang}, "
                f"speed={speed}, instruct={instruct!r}, text_length={len(text)}"
            )
            start_time = time.time()

            with tempfile.TemporaryDirectory() as tmpdir:
                _capture = TqdmCapture(_progress, sys.stderr)
                sys.stderr = _capture
                try:
                    generate_audio(
                        text=text,
                        model=model,
                        voice=voice_name,
                        lang_code=lang,
                        instruct=instruct,
                        speed=speed,
                        output_path=tmpdir,
                        file_prefix="speech",
                        audio_format="wav",
                        verbose=True,
                        play=False,
                        join_audio=True,
                    )
                finally:
                    sys.stderr = _capture._original

                wav_data = _read_wav_from_dir(tmpdir, "speech")
    finally:
        _progress.finish()

    elapsed = time.time() - start_time

    # Calculate duration from WAV data
    try:
        info = sf.info(io.BytesIO(wav_data))
        duration = info.duration
    except Exception:
        duration = max((len(wav_data) - 44) / (DEFAULT_SAMPLE_RATE * 2), 0.01)

    logger.info(
        f"Generated {duration:.2f}s audio in {elapsed:.2f}s "
        f"(RTF: {elapsed / max(duration, 0.01):.2f}, mode={mode})"
    )

    return wav_data


def _normalize_ocr_text(text: str) -> str:
    """Normalize OCR-extracted text from books/documents.

    Fixes common OCR artifacts:
    - Hyphenated words split across lines ("acti-\\ntud" → "actitud")
    - Single line breaks from column layout → spaces
    - Standalone page numbers
    - Multiple spaces
    """
    import re

    # 1. Join words split by end-of-line hyphen
    text = re.sub(r"(\w)-\s*\n\s*(\w)", r"\1\2", text)

    # 2. Remove standalone page numbers
    text = re.sub(r"(?m)^\s*\d{1,4}\s*$", "", text)

    # 3. Single line breaks → spaces (keep paragraph breaks: double newline)
    text = re.sub(r"(?<!\n)\n(?!\n)", " ", text)

    # 4. Collapse multiple spaces
    text = re.sub(r" {2,}", " ", text)

    # 5. Normalize excessive paragraph breaks
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


def _split_text_for_cloning(text: str, max_chars: int = 600) -> list[str]:
    """Split long text into segments suitable for ICL voice cloning.

    The Qwen3-TTS Base model in ICL mode does NOT split text internally —
    it processes the entire text in one shot and often emits EOS after a
    single paragraph.  We split the text ourselves and generate each
    segment separately (all with the same reference audio for voice
    consistency), then concatenate.

    The text is first normalized (OCR artifacts cleaned) and then split
    by sentence boundaries to produce segments of ~200-600 characters.
    """
    import re

    # Normalize OCR artifacts before splitting
    text = _normalize_ocr_text(text)

    # Split by paragraph (double newline)
    raw_paragraphs = [p.strip() for p in re.split(r"\n\n+", text) if p.strip()]

    segments: list[str] = []
    for para in raw_paragraphs:
        if len(para) <= max_chars:
            segments.append(para)
        else:
            # Split long paragraph by sentences
            sentences = re.split(r"(?<=[.!?])\s+", para)
            buf = ""
            for sent in sentences:
                if buf and len(buf) + len(sent) + 1 > max_chars:
                    segments.append(buf.strip())
                    buf = ""
                buf += (" " if buf else "") + sent
            if buf.strip():
                segments.append(buf.strip())

    return segments


# ---------------------------------------------------------------------------
# Voice Cloning Optimizations
# ---------------------------------------------------------------------------

# Cache for optimized reference audio paths, keyed by SHA-256 of original file.
# Avoids re-trimming / resampling the same reference audio on every segment.
_optimized_audio_cache: dict[str, str] = {}

# Cache for voice clone prompts (ICL embeddings), keyed by (audio_hash, ref_text).
# This avoids recomputing the voice embedding for every segment when cloning
# the same reference audio multiple times.
_voice_prompt_cache: dict[str, object] = {}


def _hash_file(path: str) -> str:
    """Compute SHA-256 hash of a file's contents."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _optimize_reference_audio(audio_path: str, max_duration: float = 10.0) -> str:
    """Optimize reference audio for faster cloning.

    1. Trim to *max_duration* seconds (longer doesn't help quality).
    2. Convert to mono if stereo.
    3. Resample to 24 kHz if the sample rate is different.

    The result is cached so that repeated calls with the same file are
    essentially free.
    """
    file_hash = _hash_file(audio_path)
    if file_hash in _optimized_audio_cache:
        cached = _optimized_audio_cache[file_hash]
        if os.path.exists(cached):
            logger.info(f"Using cached optimized reference audio: {cached}")
            return cached

    audio, sr = sf.read(audio_path, dtype="float32")

    # Mono
    if len(audio.shape) > 1:
        audio = audio.mean(axis=1)
        logger.info("Converted reference audio to mono")

    # Trim to max_duration
    max_samples = int(sr * max_duration)
    if len(audio) > max_samples:
        audio = audio[:max_samples]
        logger.info(f"Trimmed reference audio to {max_duration}s")

    # Resample to 24 kHz
    if sr != 24000:
        try:
            from scipy.signal import resample as scipy_resample

            new_len = int(len(audio) * 24000 / sr)
            audio = scipy_resample(audio, new_len).astype(np.float32)
            logger.info(f"Resampled reference audio from {sr} Hz to 24000 Hz")
        except ImportError:
            # scipy not available — skip resampling
            logger.warning("scipy not installed; skipping resample")
        sr = 24000

    optimized_path = os.path.join(
        tempfile.gettempdir(), f"optimized_ref_{file_hash[:12]}.wav"
    )
    sf.write(optimized_path, audio, sr, format="WAV", subtype="PCM_16")
    _optimized_audio_cache[file_hash] = optimized_path
    logger.info(f"Optimized reference audio saved to {optimized_path}")
    return optimized_path


def _get_cached_voice_prompt(model, ref_audio_path: str, ref_text: str | None):
    """Try to pre-compute and cache the voice clone prompt (ICL embedding).

    This avoids re-processing the reference audio for every text segment.
    If the model doesn't expose a lower-level prompt API, returns None
    and the caller falls back to passing ref_audio on every call.
    """
    audio_hash = _hash_file(ref_audio_path)[:16]
    cache_key = f"{audio_hash}_{ref_text or ''}"

    if cache_key in _voice_prompt_cache:
        logger.info(f"[Cache HIT] Reusing cached voice prompt: {audio_hash}")
        return _voice_prompt_cache[cache_key]

    # Try to use model's lower-level API to pre-compute the prompt
    try:
        if hasattr(model, "create_voice_clone_prompt"):
            logger.info(f"[Cache MISS] Pre-computing voice prompt: {audio_hash}")
            prompt = model.create_voice_clone_prompt(
                ref_audio=ref_audio_path,
                ref_text=ref_text,
            )
            _voice_prompt_cache[cache_key] = prompt
            logger.info(f"[Cache] Voice prompt cached: {audio_hash}")
            return prompt
    except Exception as e:
        logger.warning(f"Failed to pre-compute voice prompt: {e}")

    return None


def clone_voice(
    text: str,
    reference_audio_path: str,
    language: str = "auto",
    ref_text: str | None = None,
    speed: float = 1.0,
    x_vector_only: bool = False,
    fast_model: bool = False,
    accent_instruct: str | None = None,
) -> bytes:
    """
    Synthesize speech using a cloned voice from reference audio.

    Voice cloning uses the Base model (not CustomVoice) via In-Context Learning (ICL).
    The Base model requires ref_audio + ref_text. If ref_text is not provided,
    Whisper will auto-transcribe the reference audio.

    For long texts the input is split into segments and each segment is
    generated independently (with the same reference audio for voice
    consistency).  The resulting audio chunks are concatenated with a
    small silence gap between them.

    Args:
        text: Text to synthesize
        reference_audio_path: Path to reference audio file (3+ seconds)
        language: Language code or "auto"
        ref_text: Transcript of the reference audio (optional, Whisper auto-transcribes if omitted)
        speed: Speech speed multiplier
        x_vector_only: If True, use x-vector only mode (faster, slightly less accurate)
        fast_model: If True, use the lighter 0.6B Base model instead of 1.7B
        accent_instruct: Optional accent instruction to steer pronunciation (e.g. "Speak with Castilian Spanish accent")

    Returns:
        WAV audio data as bytes
    """
    from mlx_audio.tts.generate import generate_audio

    # Voice cloning requires the Base model (ICL mode)
    model_type = MODEL_TYPE_BASE_FAST if fast_model else MODEL_TYPE_BASE
    model = _model_manager.get_model(model_type)

    # Optimize reference audio (trim, mono, resample) — cached per file hash
    reference_audio_path = _optimize_reference_audio(reference_audio_path)

    speed = max(0.5, min(2.0, speed))
    lang = _map_language(language)

    logger.info(
        f"Cloning voice: ref={reference_audio_path}, lang={lang}, "
        f"speed={speed}, ref_text={ref_text!r}, text_length={len(text)}, "
        f"x_vector_only={x_vector_only}, fast_model={fast_model}, "
        f"accent_instruct={accent_instruct!r}"
    )

    # Diagnostic: check if ref_text is missing
    if not ref_text:
        logger.warning("ref_text is missing. mlx-audio will attempt to use Whisper for auto-transcription.")
        logger.warning("If this fails with 'Processor not found', you MUST provide the 'ref_text' field.")

    # Try to pre-compute and cache the voice prompt for multi-segment efficiency
    cached_prompt = _get_cached_voice_prompt(model, reference_audio_path, ref_text)

    # Split text into manageable segments.
    # The ICL generation path does NOT split text internally — it processes
    # the whole text in one pass and frequently emits EOS after a single
    # paragraph, producing only partial audio.
    segments = _split_text_for_cloning(text)
    logger.info(f"Split text into {len(segments)} segments for ICL cloning")

    _progress.start(len(segments), "clone")

    start_time = time.time()
    all_audio_samples: list[np.ndarray] = []
    sample_rate = DEFAULT_SAMPLE_RATE

    # Small silence gap between segments (0.3s at 24kHz)
    silence_gap = np.zeros(int(DEFAULT_SAMPLE_RATE * 0.3), dtype=np.float32)

    try:
        for seg_idx, segment in enumerate(segments):
            # Check for cancellation before starting each segment
            if _progress.is_cancelled:
                logger.info(f"Generation cancelled by user after {seg_idx} segments")
                break

            _progress.update(
                seg_idx,
                f"Generating segment {seg_idx + 1}/{len(segments)}..."
            )
            logger.info(
                f"Generating segment {seg_idx + 1}/{len(segments)} "
                f"({len(segment)} chars): {segment[:60]!r}..."
            )

            try:
                with tempfile.TemporaryDirectory() as tmpdir:
                    # Calculate dynamic max_new_tokens based on text length
                    # (~0.8 audio tokens per char is a rough estimate)
                    estimated_tokens = max(int(len(segment) * 0.8), 100)
                    max_tokens = min(estimated_tokens, 2048)

                    gen_kwargs = dict(
                        text=segment,
                        model=model,
                        lang_code=lang,
                        ref_audio=reference_audio_path,
                        ref_text=ref_text,
                        speed=speed,
                        output_path=tmpdir,
                        file_prefix="cloned",
                        audio_format="wav",
                        verbose=True,
                        play=False,
                        max_new_tokens=max_tokens,
                    )

                    # Accent instruct: steer pronunciation without changing voice timbre
                    if accent_instruct:
                        gen_kwargs["instruct"] = accent_instruct

                    # If we have a cached prompt, use it instead of ref_audio
                    if cached_prompt is not None:
                        gen_kwargs["voice_clone_prompt"] = cached_prompt
                        # Still keep ref_audio/ref_text as fallback context

                    # x_vector_only_mode: faster cloning (skips full conditioning)
                    if x_vector_only:
                        gen_kwargs["x_vector_only_mode"] = True

                    _capture = TqdmCapture(_progress, sys.stderr)
                    sys.stderr = _capture
                    try:
                        generate_audio(**gen_kwargs)
                    finally:
                        sys.stderr = _capture._original

                    wav_data = _read_wav_from_dir(tmpdir, "cloned")

                # Decode WAV bytes into numpy samples
                audio_samples, sr = sf.read(io.BytesIO(wav_data), dtype="float32")
                sample_rate = sr
                all_audio_samples.append(audio_samples)

                seg_duration = len(audio_samples) / sr
                _progress.update(
                    seg_idx + 1,
                    f"Segment {seg_idx + 1}/{len(segments)} done ({seg_duration:.1f}s)"
                )
                logger.info(
                    f"Segment {seg_idx + 1} done: {seg_duration:.2f}s audio"
                )

            except Exception as seg_err:
                error_str = str(seg_err)
                if "Processor not found" in error_str or "ref_text" in error_str:
                    raise RuntimeError(
                        "Cloning requires 'ref_text' because auto-transcription "
                        "(Whisper) is unavailable or failing. Please provide the "
                        "transcript of your reference audio."
                    )
                logger.error(f"Error generating segment {seg_idx + 1}: {seg_err}")
                _progress.update(
                    seg_idx + 1,
                    f"Segment {seg_idx + 1} failed, continuing..."
                )
                # Continue with remaining segments instead of aborting entirely
                continue
    finally:
        _progress.finish()

    if _progress.is_cancelled and not all_audio_samples:
        raise RuntimeError("Generation cancelled by user")

    if not all_audio_samples:
        raise RuntimeError("No audio was generated for any text segment")

    # Concatenate all segments with silence gaps
    parts: list[np.ndarray] = []
    for i, samples in enumerate(all_audio_samples):
        if i > 0:
            parts.append(silence_gap)
        parts.append(samples)

    combined = np.concatenate(parts)

    # Encode back to WAV bytes
    buf = io.BytesIO()
    sf.write(buf, combined, sample_rate, format="WAV", subtype="PCM_16")
    wav_data = buf.getvalue()

    elapsed = time.time() - start_time
    total_duration = len(combined) / sample_rate
    logger.info(
        f"Cloned {total_duration:.2f}s audio ({len(segments)} segments) "
        f"in {elapsed:.2f}s"
    )

    return wav_data


def _read_wav_from_dir(tmpdir: str, prefix: str) -> bytes:
    """Read and concatenate all generated WAV files from a temp directory.

    mlx-audio may produce multiple numbered chunks (e.g. cloned_0.wav,
    cloned_1.wav) for long texts.  When ``join_audio=True`` is passed to
    ``generate_audio`` a single file is written, but as a safety net this
    function also handles the multi-file case by concatenating all chunks
    in sorted order.
    """
    # 1. Check for a single joined file first (produced when join_audio=True)
    wav_path = os.path.join(tmpdir, f"{prefix}.wav")
    if os.path.exists(wav_path):
        with open(wav_path, "rb") as f:
            return f.read()

    # 2. Gather all wav files and sort by name to maintain chunk order
    wav_files = sorted(f for f in os.listdir(tmpdir) if f.endswith(".wav"))
    if not wav_files:
        raise RuntimeError("No WAV file generated by mlx-audio")

    if len(wav_files) == 1:
        with open(os.path.join(tmpdir, wav_files[0]), "rb") as f:
            return f.read()

    # 3. Multiple chunk files — concatenate PCM samples
    logger.info(f"Found {len(wav_files)} WAV chunks, concatenating: {wav_files}")
    all_samples = []
    sample_rate = None
    for fname in wav_files:
        fpath = os.path.join(tmpdir, fname)
        data, sr = sf.read(fpath, dtype="float32")
        if sample_rate is None:
            sample_rate = sr
        all_samples.append(data)

    combined = np.concatenate(all_samples)
    buf = io.BytesIO()
    sf.write(buf, combined, sample_rate, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def _resolve_voice_key(speaker: str) -> str:
    """Resolve a speaker name to a valid VOICES key (case-insensitive)."""
    # Exact match
    if speaker in VOICES:
        return speaker
    # Case-insensitive match
    lower = speaker.lower()
    for key in VOICES:
        if key.lower() == lower:
            return key
    logger.warning(f"Unknown speaker '{speaker}', falling back to Vivian")
    return "Vivian"


def _map_language(language: str) -> str:
    """Map language code for mlx-audio. 'auto' maps to 'en' as default."""
    if language == "auto" or not language:
        return "en"
    return language


# =============================================================================
# API Endpoints
# =============================================================================


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint. Does NOT force-load any model."""
    status = _model_manager.status()

    # MLX device info (GPU verification)
    try:
        import mlx.core as mx
        device = str(mx.default_device())
    except Exception:
        device = "unknown"

    return jsonify({
        "status": "ok",
        "service": "qwen3-tts-mlx",
        "loaded_model": status["loaded_model"],
        "device": device,
    })


@app.route("/progress", methods=["GET"])
def progress():
    """Return current generation progress (polled by the Swift client)."""
    return jsonify(_progress.get_state())


@app.route("/cancel", methods=["POST"])
def cancel():
    """Cancel the current generation in progress."""
    state = _progress.get_state()
    if not state["active"]:
        return jsonify({"cancelled": False, "reason": "No active generation"})

    _progress.cancel()
    logger.info("Generation cancelled by client request")
    return jsonify({"cancelled": True})


@app.route("/models", methods=["GET"])
def list_models():
    """List available models and which one is currently loaded."""
    status = _model_manager.status()
    loaded = status["loaded_model"]

    return jsonify({
        "loaded_model": loaded,
        "loaded_model_id": status["loaded_model_id"],
        "load_count": status["load_count"],
        "available": {
            "custom_voice": {
                "id": CUSTOM_VOICE_MODEL_ID,
                "loaded": loaded == MODEL_TYPE_CUSTOM_VOICE,
            },
            "voice_design": {
                "id": VOICE_DESIGN_MODEL_ID,
                "loaded": loaded == MODEL_TYPE_VOICE_DESIGN,
            },
            "base": {
                "id": BASE_MODEL_ID,
                "loaded": loaded == MODEL_TYPE_BASE,
                "usage": "Voice cloning (ICL mode)",
            },
            "base_fast": {
                "id": BASE_MODEL_FAST_ID,
                "loaded": loaded == MODEL_TYPE_BASE_FAST,
                "usage": "Voice cloning fast (0.6B, lower quality)",
            },
        },
    })


@app.route("/voices", methods=["GET"])
def list_voices():
    """List available voices."""
    voice_list = []
    for voice_id, info in VOICES.items():
        voice_list.append(
            {
                "id": voice_id,
                "name": info["name"],
                "language": info["language"],
                "gender": info["gender"],
                "style": info["style"],
            }
        )

    voice_list.sort(key=lambda v: v["name"])

    return jsonify({"voices": voice_list, "count": len(voice_list)})


@app.route("/synthesize", methods=["POST"])
def synthesize():
    """
    Synthesize text to speech.

    Request JSON:
        CustomVoice mode (default):
        {
            "text": "Hello, world!",
            "speaker": "Vivian",
            "language": "auto",
            "instruct": "Speak with a happy tone",
            "speed": 1.0,
            "mode": "custom_voice"
        }

        VoiceDesign mode (for languages without native speaker):
        {
            "text": "Hola mundo",
            "language": "es",
            "instruct": "A warm female voice with native Spanish accent from Spain",
            "speed": 1.0,
            "mode": "voice_design"
        }

    Returns:
        audio/wav binary data
    """
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()

    text = data.get("text")
    if not text:
        return jsonify({"error": "Missing 'text' field"}), 400

    if len(text) > 10000:
        return jsonify({"error": "Text too long (max 10000 characters)"}), 400

    speaker = data.get("speaker", "Vivian")
    language = data.get("language", "auto")
    instruct = data.get("instruct")
    speed = data.get("speed", DEFAULT_SPEED)
    mode = data.get("mode", "custom_voice")

    logger.info(f"[DIAG] /synthesize received: mode={mode}, speaker={speaker}, language={language}, speed={speed}")
    logger.info(f"[DIAG] /synthesize instruct: {instruct!r}")
    logger.info(f"[DIAG] /synthesize text ({len(text)} chars): {text[:80]!r}")

    # Validate mode
    if mode not in ("custom_voice", "voice_design"):
        return jsonify({"error": f"Invalid mode '{mode}'. Must be 'custom_voice' or 'voice_design'"}), 400

    # VoiceDesign requires instruct
    if mode == "voice_design" and not instruct:
        return jsonify({"error": "VoiceDesign mode requires 'instruct' field with voice description"}), 400

    try:
        speed = float(speed)
    except (TypeError, ValueError):
        speed = DEFAULT_SPEED

    try:
        wav_data = synthesize_speech(
            text=text,
            speaker=speaker,
            language=language,
            instruct=instruct,
            speed=speed,
            mode=mode,
        )

        return Response(
            wav_data,
            mimetype="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=speech.wav",
                "Content-Length": len(wav_data),
            },
        )

    except Exception as e:
        logger.exception("Synthesis failed")
        return jsonify({"error": str(e)}), 500


@app.route("/clone", methods=["POST"])
def clone():
    """
    Voice cloning from reference audio (uses Base model via ICL).

    Request: multipart/form-data
        - audio: WAV/MP3/M4A file (3+ seconds)
        - text: Text to synthesize
        - language: Language code (optional, default: "auto")
        - ref_text: Transcript of the reference audio (optional, auto-transcribed via Whisper if omitted)
        - speed: Speed multiplier (optional, default: 1.0)
        - x_vector_only: "true"/"false" — faster cloning with less accuracy (optional, default: false)
        - fast_model: "true"/"false" — use lighter 0.6B model (optional, default: false)
        - accent_instruct: Accent steering instruction (optional, e.g. "Speak with Castilian Spanish accent from Spain")

    Returns:
        audio/wav binary data
    """
    if "audio" not in request.files:
        return jsonify({"error": "Missing 'audio' file"}), 400

    audio_file = request.files["audio"]
    text = request.form.get("text")
    if not text:
        return jsonify({"error": "Missing 'text' field"}), 400

    if len(text) > 10000:
        return jsonify({"error": "Text too long (max 10000 characters)"}), 400

    language = request.form.get("language", "auto")
    ref_text = request.form.get("ref_text")  # Transcript of reference audio (optional)
    speed = request.form.get("speed", str(DEFAULT_SPEED))
    x_vector_only = request.form.get("x_vector_only", "false").lower() == "true"
    fast_model = request.form.get("fast_model", "false").lower() == "true"
    accent_instruct = request.form.get("accent_instruct")  # Accent steering (optional)

    try:
        speed = float(speed)
    except (TypeError, ValueError):
        speed = DEFAULT_SPEED

    logger.info(f"Clone params: x_vector_only={x_vector_only}, fast_model={fast_model}, accent_instruct={accent_instruct!r}")

    # Save reference audio to temp file
    suffix = os.path.splitext(audio_file.filename or "ref.wav")[1] or ".wav"
    # Use mkstemp to get a path and close the fd immediately to avoid locks
    fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    
    try:
        logger.info(f"Saving uploaded reference audio to {tmp_path}")
        audio_file.save(tmp_path)
        
        # Validate duration (minimum 3 seconds, maximum 30 seconds recommended)
        try:
            info = sf.info(tmp_path)
            if info.duration < 3.0:
                return jsonify({"error": f"Reference audio too short ({info.duration:.1f}s). Minimum 3 seconds required."}), 400
            
            if info.duration > 60.0:
                logger.warning(f"Reference audio very long ({info.duration:.1f}s). This may cause [Errno 5] or memory issues.")
                # We don't block it, but we log it clearly.
                
            logger.info(f"Reference audio validated: duration={info.duration:.1f}s, format={info.format}")
        except Exception as sf_err:
            logger.error(f"Soundfile failed to read reference audio: {sf_err}")
            return jsonify({"error": f"Invalid audio format or corrupt file: {str(sf_err)}"}), 400

        logger.info(f"Starting voice cloning: text_len={len(text)}, lang={language}, speed={speed}")

        wav_data = clone_voice(
            text=text,
            reference_audio_path=tmp_path,
            language=language,
            ref_text=ref_text,
            speed=speed,
            x_vector_only=x_vector_only,
            fast_model=fast_model,
            accent_instruct=accent_instruct,
        )

        return Response(
            wav_data,
            mimetype="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=speech.wav",
                "Content-Length": len(wav_data),
            },
        )

    except Exception as e:
        logger.exception("Voice cloning failed")
        # Provide a more descriptive error if it's a known OS error
        error_msg = str(e)
        if "[Errno 5]" in error_msg:
            error_msg = "Input/Output error during cloning. This often happens if the system is out of memory or the audio file format is problematic on macOS."
        return jsonify({"error": f"Qwen3 MLX clone error: {error_msg}"}), 500

    finally:
        try:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                logger.info(f"Temporary file {tmp_path} cleaned up")
        except OSError:
            pass


@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Transcribe audio to text using mlx-whisper.

    Request: multipart/form-data
        - audio: WAV/MP3/M4A file

    Returns:
        JSON { "text": "transcribed text" }
    """
    if "audio" not in request.files:
        return jsonify({"error": "Missing 'audio' file"}), 400

    audio_file = request.files["audio"]

    # Save to temp file
    suffix = os.path.splitext(audio_file.filename or "audio.wav")[1] or ".wav"
    fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)

    try:
        audio_file.save(tmp_path)
        logger.info(f"Transcribing audio: {tmp_path}")

        import mlx_whisper

        result = mlx_whisper.transcribe(
            tmp_path,
            path_or_hf_repo="mlx-community/whisper-base-mlx",
        )

        text = result.get("text", "").strip()
        logger.info(f"Transcription result ({len(text)} chars): {text[:120]!r}")

        return jsonify({"text": text})

    except ImportError:
        logger.error("mlx-whisper not installed. Install with: pip install mlx-whisper")
        return jsonify({"error": "mlx-whisper not installed on server"}), 500

    except Exception as e:
        logger.exception("Transcription failed")
        return jsonify({"error": str(e)}), 500

    finally:
        try:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
        except OSError:
            pass


@app.route("/benchmark", methods=["POST"])
def benchmark():
    """Measure generation speed to diagnose performance issues.

    Returns tokens/s estimate, device info, and timing.
    """
    test_text = "This is a benchmark test for measuring generation speed on Apple Silicon."

    start = time.time()
    try:
        model = get_custom_voice_model()

        from mlx_audio.tts.generate import generate_audio

        with tempfile.TemporaryDirectory() as tmpdir:
            generate_audio(
                text=test_text,
                model=model,
                voice="Ryan",
                lang_code="en",
                speed=1.0,
                output_path=tmpdir,
                file_prefix="bench",
                audio_format="wav",
                verbose=False,
                play=False,
                join_audio=True,
            )

            wav_data = _read_wav_from_dir(tmpdir, "bench")

        elapsed = time.time() - start

        try:
            info = sf.info(io.BytesIO(wav_data))
            audio_duration = info.duration
        except Exception:
            audio_duration = max((len(wav_data) - 44) / (DEFAULT_SAMPLE_RATE * 2), 0.01)

        return jsonify({
            "status": "ok",
            "device": str(mx.default_device()),
            "metal_available": mx.metal.is_available() if hasattr(mx, "metal") else "unknown",
            "text_length": len(test_text),
            "generation_time_s": round(elapsed, 2),
            "audio_duration_s": round(audio_duration, 2),
            "rtf": round(elapsed / max(audio_duration, 0.01), 2),
            "estimated_tokens_per_sec": int(len(test_text) * 0.8 / max(elapsed, 0.01)),
            "model_loaded": _model_manager.current_type,
        })

    except Exception as e:
        elapsed = time.time() - start
        logger.exception("Benchmark failed")
        return jsonify({
            "status": "error",
            "error": str(e),
            "elapsed": round(elapsed, 2),
            "device": str(mx.default_device()),
        }), 500


@app.route("/unload", methods=["POST"])
def unload():
    """
    Unload the currently loaded model to free memory.

    Returns:
        JSON with status and freed model type.
    """
    status = _model_manager.status()
    previous = status["loaded_model"]

    if _model_manager.unload():
        logger.info(f"Model unloaded via /unload endpoint (was: {previous})")
        return jsonify({
            "status": "ok",
            "unloaded": previous,
            "message": f"Model '{previous}' unloaded, memory freed",
        })
    else:
        return jsonify({
            "status": "ok",
            "unloaded": None,
            "message": "No model was loaded",
        })


@app.route("/", methods=["GET"])
def index():
    """API information."""
    return jsonify(
        {
            "service": "Qwen3-TTS MLX Server",
            "models": {
                "custom_voice": CUSTOM_VOICE_MODEL_ID,
                "voice_design": VOICE_DESIGN_MODEL_ID,
                "base": BASE_MODEL_ID,
            },
            "endpoints": {
                "GET /health": "Health check",
                "GET /voices": "List available voices (9 premium speakers)",
                "GET /models": "List loaded/available models",
                "GET /progress": "Current generation progress (poll while synthesizing)",
                "POST /synthesize": "Text to speech (custom_voice or voice_design mode)",
                "POST /clone": "Voice cloning from reference audio",
                "POST /transcribe": "Transcribe audio to text (mlx-whisper)",
                "POST /benchmark": "Measure generation speed (tokens/s)",
                "POST /unload": "Unload current model to free memory",
            },
            "features": {
                "emotions": "Use 'instruct' field for emotion/style control (custom_voice mode)",
                "voice_design": "Use mode='voice_design' with 'instruct' describing the voice for languages without native speaker",
                "cloning": "Upload 3+ second audio reference for voice cloning",
                "languages": SUPPORTED_LANGUAGES,
            },
        }
    )


# =============================================================================
# Main
# =============================================================================


def print_system_info():
    """Print system diagnostics at startup to verify GPU and memory."""
    print("=" * 55)
    print("  SYSTEM INFO")
    print("=" * 55)
    print(f"  Platform:      {platform.platform()}")
    print(f"  Processor:     {platform.processor()}")
    try:
        import psutil
        mem = psutil.virtual_memory()
        print(f"  RAM Total:     {mem.total / 1e9:.1f} GB")
        print(f"  RAM Available: {mem.available / 1e9:.1f} GB")
    except ImportError:
        print("  RAM:           (install psutil for memory info)")
    print(f"  MLX Device:    {mx.default_device()}")
    try:
        print(f"  MLX Metal:     {mx.metal.is_available()}")
    except AttributeError:
        print("  MLX Metal:     (check not available in this mlx version)")
    print("=" * 55)


def main():
    global VOICE_DESIGN_MODEL_ID
    parser = argparse.ArgumentParser(
        description="Qwen3-TTS MLX Server for ReaderPro",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python qwen3_mlx_server.py                    # Run on localhost:8890
    python qwen3_mlx_server.py --port 9000        # Run on custom port
    python qwen3_mlx_server.py --host 0.0.0.0     # Allow external connections

API Usage:
    # Health check
    curl http://localhost:8890/health

    # List voices
    curl http://localhost:8890/voices

    # List models
    curl http://localhost:8890/models

    # Synthesize speech (CustomVoice mode - default)
    curl -X POST http://localhost:8890/synthesize \\
         -H "Content-Type: application/json" \\
         -d '{"text": "Hello!", "speaker": "Vivian", "instruct": "Speak happily"}' \\
         --output speech.wav

    # Synthesize speech (VoiceDesign mode - for Spanish, French, etc.)
    curl -X POST http://localhost:8890/synthesize \\
         -H "Content-Type: application/json" \\
         -d '{"text": "Hola mundo", "mode": "voice_design", "instruct": "A warm female voice with native Spanish accent", "language": "es"}' \\
         --output speech.wav

    # Voice cloning
    curl -X POST http://localhost:8890/clone \\
         -F "audio=@reference.wav" \\
         -F "text=Hello world" \\
         --output cloned.wav
        """,
    )
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8890, help="Port to listen on (default: 8890)")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")
    parser.add_argument(
        "--voice-design-model",
        default=VOICE_DESIGN_MODEL_ID,
        help=f"VoiceDesign model ID (default: {VOICE_DESIGN_MODEL_ID})",
    )

    args = parser.parse_args()

    # Allow overriding VoiceDesign model from CLI
    VOICE_DESIGN_MODEL_ID = args.voice_design_model

    print(
        f"""
╔═══════════════════════════════════════════════════════════════╗
║            Qwen3-TTS MLX Server (Lazy Loading)                ║
╠═══════════════════════════════════════════════════════════════╣
║  CustomVoice:  {CUSTOM_VOICE_MODEL_ID:<44s}║
║  VoiceDesign:  {VOICE_DESIGN_MODEL_ID:<44s}║
║  Base (clone): {BASE_MODEL_ID:<44s}║
║  Base fast:    {BASE_MODEL_FAST_ID:<44s}║
║                                                               ║
║  Memory: Only ONE model loaded at a time (saves ~6-9GB RAM)  ║
║  Models load on first request, unload when switching.         ║
║                                                               ║
║  Endpoints:                                                   ║
║    GET  /health      - Health check                           ║
║    GET  /voices      - List available voices                  ║
║    GET  /models      - List loaded models                     ║
║    GET  /progress    - Generation progress (poll)             ║
║    POST /synthesize  - TTS (custom_voice / voice_design)      ║
║    POST /clone       - Voice cloning via ICL (Base model)     ║
║    POST /transcribe  - Audio to text (mlx-whisper)            ║
║    POST /benchmark   - Measure generation speed               ║
║    POST /unload      - Free memory (unload current model)     ║
╠═══════════════════════════════════════════════════════════════╣
║  Server: http://{args.host}:{args.port:<43d}║
╚═══════════════════════════════════════════════════════════════╝
    """
    )

    print_system_info()
    logger.info("Server ready! Models will load on demand (no pre-loading).")

    app.run(host=args.host, port=args.port, debug=args.debug, threaded=True)


if __name__ == "__main__":
    main()
