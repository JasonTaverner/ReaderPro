#!/usr/bin/env python3
"""
Kokoro TTS Server for ReaderPro

A lightweight HTTP server that provides Text-to-Speech synthesis using Kokoro.
Designed to work with the KokoroTTSAdapter in the ReaderPro macOS app.

Endpoints:
    GET  /health     - Health check
    GET  /voices     - List available voices
    POST /synthesize - Convert text to speech (returns WAV)

Usage:
    python kokoro_server.py [--port PORT] [--host HOST]

Requirements:
    pip install kokoro-onnx soundfile numpy flask

Author: ReaderPro Team
"""

import argparse
import glob
import io
import json
import logging
import os
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from flask import Flask, Response, jsonify, request
from scipy import signal

# Default search paths for Kokoro model files
DEFAULT_MODEL_PATHS = [
    Path.home() / "repos2" / "ReaderPro",  # Primary location
    Path.cwd(),  # Current directory
    Path(__file__).parent.parent,  # Parent of scripts directory
    Path(__file__).parent,  # Scripts directory
]

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global Kokoro pipeline instance (lazy initialization)
_kokoro_pipeline = None
_available_voices = None

# Default configuration
DEFAULT_SAMPLE_RATE = 24000
DEFAULT_SPEED = 1.0


def find_model_file(pattern: str, search_paths: list[Path]) -> str | None:
    """
    Find a model file matching the pattern in the search paths.

    Args:
        pattern: Glob pattern (e.g., "kokoro*.onnx")
        search_paths: List of directories to search

    Returns:
        Full path to the file, or None if not found
    """
    for search_path in search_paths:
        if not search_path.exists():
            continue

        matches = list(search_path.glob(pattern))
        if matches:
            # Return the first match (or most recent if multiple)
            matches.sort(key=lambda p: p.stat().st_mtime, reverse=True)
            return str(matches[0])

    return None


def get_kokoro_pipeline():
    """Lazy initialization of Kokoro pipeline."""
    global _kokoro_pipeline

    if _kokoro_pipeline is None:
        try:
            from kokoro_onnx import Kokoro

            logger.info("Initializing Kokoro TTS pipeline...")
            logger.info(f"Searching for model files in: {[str(p) for p in DEFAULT_MODEL_PATHS]}")
            start_time = time.time()

            # Find model files with pattern matching
            model_path = find_model_file("kokoro*.onnx", DEFAULT_MODEL_PATHS)
            voices_path = find_model_file("voices*.bin", DEFAULT_MODEL_PATHS)

            if not model_path:
                raise FileNotFoundError(
                    "Could not find Kokoro model file (kokoro*.onnx). "
                    f"Searched in: {[str(p) for p in DEFAULT_MODEL_PATHS]}"
                )

            if not voices_path:
                raise FileNotFoundError(
                    "Could not find voices file (voices*.bin). "
                    f"Searched in: {[str(p) for p in DEFAULT_MODEL_PATHS]}"
                )

            logger.info(f"Found model: {model_path}")
            logger.info(f"Found voices: {voices_path}")

            # Initialize Kokoro with found model files
            _kokoro_pipeline = Kokoro(model_path, voices_path)

            elapsed = time.time() - start_time
            logger.info(f"Kokoro initialized in {elapsed:.2f}s")

        except ImportError as e:
            logger.error(f"Failed to import kokoro-onnx: {e}")
            logger.error("Install with: pip install kokoro-onnx")
            raise
        except FileNotFoundError as e:
            logger.error(str(e))
            raise
        except Exception as e:
            logger.error(f"Failed to initialize Kokoro: {e}")
            raise

    return _kokoro_pipeline


def get_available_voices():
    """Get list of available Kokoro voices."""
    global _available_voices

    if _available_voices is None:
        # Kokoro v0.19 default voices
        # Format: voice_id -> {name, language, style}
        _available_voices = {
            # American English
            "af_bella": {"name": "Bella", "language": "en-US", "style": "default"},
            "af_nicole": {"name": "Nicole", "language": "en-US", "style": "default"},
            "af_sarah": {"name": "Sarah", "language": "en-US", "style": "default"},
            "af_sky": {"name": "Sky", "language": "en-US", "style": "default"},
            "am_adam": {"name": "Adam", "language": "en-US", "style": "default"},
            "am_michael": {"name": "Michael", "language": "en-US", "style": "default"},

            # British English
            "bf_emma": {"name": "Emma", "language": "en-GB", "style": "default"},
            "bf_isabella": {"name": "Isabella", "language": "en-GB", "style": "default"},
            "bm_george": {"name": "George", "language": "en-GB", "style": "default"},
            "bm_lewis": {"name": "Lewis", "language": "en-GB", "style": "default"},

            # Japanese
            "jf_alpha": {"name": "Alpha", "language": "ja-JP", "style": "default"},
            "jf_gongitsune": {"name": "Gongitsune", "language": "ja-JP", "style": "default"},
            "jf_nezumi": {"name": "Nezumi", "language": "ja-JP", "style": "default"},
            "jf_tebukuro": {"name": "Tebukuro", "language": "ja-JP", "style": "default"},
            "jm_kumo": {"name": "Kumo", "language": "ja-JP", "style": "default"},

            # Chinese
            "zf_xiaobei": {"name": "Xiaobei", "language": "zh-CN", "style": "default"},
            "zf_xiaoni": {"name": "Xiaoni", "language": "zh-CN", "style": "default"},
            "zf_xiaoxiao": {"name": "Xiaoxiao", "language": "zh-CN", "style": "default"},
            "zf_xiaoyi": {"name": "Xiaoyi", "language": "zh-CN", "style": "default"},
            "zm_yunjian": {"name": "Yunjian", "language": "zh-CN", "style": "default"},
            "zm_yunxi": {"name": "Yunxi", "language": "zh-CN", "style": "default"},

            # Korean
            "kf_sarah": {"name": "Sarah (KR)", "language": "ko-KR", "style": "default"},
            "km_kevin": {"name": "Kevin (KR)", "language": "ko-KR", "style": "default"},

            # Spanish
            "ef_dora": {"name": "Dora", "language": "es-ES", "style": "default"},
            "em_santa": {"name": "Santa", "language": "es-ES", "style": "default"},
            "em_alex": {"name": "Alex", "language": "es-ES", "style": "default"},

            # French
            "ff_siwis": {"name": "Siwis", "language": "fr-FR", "style": "default"},

            # Hindi
            "hf_alpha": {"name": "Alpha (HI)", "language": "hi-IN", "style": "default"},
            "hf_beta": {"name": "Beta (HI)", "language": "hi-IN", "style": "default"},
            "hm_omega": {"name": "Omega (HI)", "language": "hi-IN", "style": "default"},
            "hm_psi": {"name": "Psi (HI)", "language": "hi-IN", "style": "default"},

            # Italian
            "if_sara": {"name": "Sara (IT)", "language": "it-IT", "style": "default"},
            "im_nicola": {"name": "Nicola (IT)", "language": "it-IT", "style": "default"},

            # Portuguese (Brazil)
            "pf_dora": {"name": "Dora (BR)", "language": "pt-BR", "style": "default"},
            "pm_alex": {"name": "Alex (BR)", "language": "pt-BR", "style": "default"},
        }

    return _available_voices


VOICE_PREFIX_TO_LANG = {
    "a": "en-us",   # American English
    "b": "en-gb",   # British English
    "e": "es",      # Spanish
    "f": "fr-fr",   # French
    "h": "hi",      # Hindi
    "i": "it",      # Italian
    "j": "ja",      # Japanese
    "k": "ko",      # Korean
    "p": "pt-br",   # Brazilian Portuguese
    "z": "zh",      # Chinese
}

# Map BCP-47 language tags (from the Swift app) to kokoro-onnx lang codes
LANG_TAG_TO_KOKORO = {
    "en-US": "en-us",
    "en-GB": "en-gb",
    "es-ES": "es",
    "fr-FR": "fr-fr",
    "hi-IN": "hi",
    "it-IT": "it",
    "ja-JP": "ja",
    "ko-KR": "ko",
    "pt-BR": "pt-br",
    "zh-CN": "zh",
}


def resolve_lang(voice: str, lang_hint: str | None = None) -> str:
    """
    Resolve the kokoro-onnx lang code for phonemization.

    Priority:
        1. Explicit lang_hint from the client (BCP-47 tag mapped to kokoro code)
        2. Derived from voice ID prefix (first character)
        3. Fallback to "en-us"
    """
    # 1. Try explicit hint from client
    if lang_hint:
        mapped = LANG_TAG_TO_KOKORO.get(lang_hint)
        if mapped:
            return mapped
        # Maybe the client already sent a kokoro-compatible code
        if lang_hint.lower() in VOICE_PREFIX_TO_LANG.values():
            return lang_hint.lower()

    # 2. Derive from voice prefix
    if voice and len(voice) >= 1:
        prefix = voice[0]
        if prefix in VOICE_PREFIX_TO_LANG:
            return VOICE_PREFIX_TO_LANG[prefix]

    # 3. Fallback
    return "en-us"

def apply_radio_filter(audio: np.ndarray, sr: int) -> np.ndarray:
    """Aplica filtro paso bajo y normaliza el volumen."""
    sos = signal.butter(6, 7500, 'low', fs=sr, output='sos')
    filtered = signal.sosfilt(sos, audio)
    
    max_val = np.max(np.abs(filtered))
    if max_val > 0:
        filtered = filtered / max_val * 0.95
        
    return filtered.astype(np.float32)

def synthesize_speech(text: str, voice: str, speed: float = 1.0, lang: str | None = None) -> bytes:
    """
    Synthesize speech from text using Kokoro.

    Args:
        text: Text to synthesize
        voice: Voice ID (e.g., "af_bella")
        speed: Speech speed multiplier (0.5 - 2.0)
        lang: Language tag from client (e.g., "es-ES") for correct phonemization

    Returns:
        WAV audio data as bytes
    """
    pipeline = get_kokoro_pipeline()

    # Validate voice - accept any voice in our list or common prefixes
    voices = get_available_voices()
    valid_prefixes = ["af", "am", "bf", "bm", "jf", "jm", "zf", "zm", "kf", "km", "ef", "em", "ff", "hf", "hm", "if", "im", "pf", "pm", "es"]
    original_voice = voice

    if voice not in voices:
        # Try to find a matching voice by prefix
        prefix = voice[:2] if len(voice) >= 2 else ""
        if prefix in valid_prefixes:
            # Use a default voice for this prefix
            matching = [v for v in voices.keys() if v.startswith(prefix)]
            if matching:
                voice = matching[0]
                logger.info(f"Voice '{original_voice}' -> using '{voice}'")
            else:
                voice = "af_bella"
                logger.info(f"No voice for prefix '{prefix}', using default: {voice}")
        else:
            # Completely unknown voice, use default
            voice = "af_bella"
            logger.info(f"Unknown voice '{original_voice}', using default: {voice}")

    # Resolve language for phonemization
    kokoro_lang = resolve_lang(voice, lang)

    # Clamp speed to valid range
    speed = max(0.5, min(2.0, speed))

    logger.info(f"Synthesizing: voice={voice}, lang={kokoro_lang} (hint={lang}), speed={speed}, text_length={len(text)}")
    start_time = time.time()

    # Generate audio using Kokoro with correct language for phonemization
    samples, sample_rate = pipeline.create(text, voice=voice, speed=speed, lang=kokoro_lang)

    elapsed = time.time() - start_time
    duration = len(samples) / sample_rate
    logger.info(f"Generated {duration:.2f}s audio in {elapsed:.2f}s (RTF: {elapsed/duration:.2f})")

    # Convert to WAV bytes
    wav_buffer = io.BytesIO()
    sf.write(wav_buffer, samples, sample_rate, format='WAV', subtype='PCM_16')
    wav_buffer.seek(0)

    return wav_buffer.read()


# =============================================================================
# API Endpoints
# =============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    try:
        # Try to get pipeline to verify it's working
        _ = get_kokoro_pipeline()
        return jsonify({
            "status": "ok",
            "service": "kokoro-tts",
            "version": "1.0.0"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 503


@app.route('/voices', methods=['GET'])
def list_voices():
    """List available voices."""
    voices = get_available_voices()

    # Format for API response
    voice_list = []
    for voice_id, info in voices.items():
        voice_list.append({
            "id": voice_id,
            "name": info["name"],
            "language": info["language"],
            "style": info["style"]
        })

    # Sort by language, then name
    voice_list.sort(key=lambda v: (v["language"], v["name"]))

    return jsonify({
        "voices": voice_list,
        "count": len(voice_list)
    })


@app.route('/synthesize', methods=['POST'])
def synthesize():
    """
    Synthesize text to speech.

    Request JSON:
        {
            "text": "Hello, world!",
            "voice": "af_bella",
            "speed": 1.0
        }

    Returns:
        audio/wav binary data
    """
    # Parse request
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()

    # Validate required fields
    text = data.get('text')
    if not text:
        return jsonify({"error": "Missing 'text' field"}), 400

    if len(text) > 10000:
        return jsonify({"error": "Text too long (max 10000 characters)"}), 400

    voice = data.get('voice', 'af_bella')
    speed = data.get('speed', DEFAULT_SPEED)
    lang = data.get('lang', None)

    try:
        speed = float(speed)
    except (TypeError, ValueError):
        speed = DEFAULT_SPEED

    try:
        # Generate audio
        wav_data = synthesize_speech(text, voice, speed, lang=lang)

        # Return WAV audio
        return Response(
            wav_data,
            mimetype='audio/wav',
            headers={
                'Content-Disposition': 'attachment; filename=speech.wav',
                'Content-Length': len(wav_data)
            }
        )

    except Exception as e:
        logger.exception("Synthesis failed")
        return jsonify({"error": str(e)}), 500


@app.route('/', methods=['GET'])
def index():
    """API information."""
    return jsonify({
        "service": "Kokoro TTS Server",
        "version": "1.0.0",
        "endpoints": {
            "GET /health": "Health check",
            "GET /voices": "List available voices",
            "POST /synthesize": "Convert text to speech"
        },
        "usage": {
            "synthesize": {
                "method": "POST",
                "content_type": "application/json",
                "body": {
                    "text": "Text to synthesize (required)",
                    "voice": "Voice ID (optional, default: af_bella)",
                    "speed": "Speed multiplier 0.5-2.0 (optional, default: 1.0)"
                }
            }
        }
    })


# =============================================================================
# Main
# =============================================================================

def main():
    global DEFAULT_MODEL_PATHS

    parser = argparse.ArgumentParser(
        description='Kokoro TTS Server for ReaderPro',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python kokoro_server.py                    # Run on localhost:8880
    python kokoro_server.py --port 9000        # Run on custom port
    python kokoro_server.py --host 0.0.0.0     # Allow external connections
    python kokoro_server.py --model-dir /path/to/models

API Usage:
    # Health check
    curl http://localhost:8880/health

    # List voices
    curl http://localhost:8880/voices

    # Synthesize speech
    curl -X POST http://localhost:8880/synthesize \\
         -H "Content-Type: application/json" \\
         -d '{"text": "Hello, world!", "voice": "af_bella", "speed": 1.0}' \\
         --output speech.wav
        """
    )
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to (default: 0.0.0.0 for all interfaces)')
    parser.add_argument('--port', type=int, default=8880, help='Port to listen on (default: 8880)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--model-dir', type=str, help='Directory containing kokoro*.onnx and voices*.bin files')

    args = parser.parse_args()

    # Add custom model directory to search paths if specified
    if args.model_dir:
        custom_path = Path(args.model_dir).expanduser().resolve()
        DEFAULT_MODEL_PATHS.insert(0, custom_path)
        logger.info(f"Added custom model directory: {custom_path}")

    print(f"""
╔═══════════════════════════════════════════════════════════════╗
║                    Kokoro TTS Server                          ║
╠═══════════════════════════════════════════════════════════════╣
║  Endpoints:                                                   ║
║    GET  /health     - Health check                            ║
║    GET  /voices     - List available voices                   ║
║    POST /synthesize - Convert text to speech                  ║
╠═══════════════════════════════════════════════════════════════╣
║  Server: http://{args.host}:{args.port}
╚═══════════════════════════════════════════════════════════════╝
    """)

    # Pre-initialize Kokoro on startup
    try:
        logger.info("Pre-loading Kokoro model...")
        get_kokoro_pipeline()
        logger.info("Server ready!")
    except Exception as e:
        logger.error(f"Failed to initialize Kokoro: {e}")
        logger.error("Server will attempt to initialize on first request")

    # Run Flask server
    app.run(
        host=args.host,
        port=args.port,
        debug=args.debug,
        threaded=True
    )


if __name__ == '__main__':
    main()
