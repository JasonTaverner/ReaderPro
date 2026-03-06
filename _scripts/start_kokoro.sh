#!/bin/bash
#
# Start Kokoro TTS Server for ReaderPro
#
# This script:
# 1. Checks if Python and dependencies are installed
# 2. Starts the Kokoro TTS server
# 3. Keeps it running in the background (optional)
#
# Usage:
#   ./start_kokoro.sh           # Run in foreground
#   ./start_kokoro.sh --daemon  # Run in background
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_SCRIPT="$SCRIPT_DIR/kokoro_server.py"
PID_FILE="$SCRIPT_DIR/.kokoro_server.pid"
LOG_FILE="$SCRIPT_DIR/kokoro_server.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if server is already running
check_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Running
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1  # Not running
}

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        echo "Install with: brew install python3"
        exit 1
    fi

    # Check pip packages
    if ! python3 -c "import flask" 2>/dev/null; then
        print_warning "Flask not installed. Installing dependencies..."
        pip3 install -r "$SCRIPT_DIR/requirements.txt"
    fi

    if ! python3 -c "import kokoro_onnx" 2>/dev/null; then
        print_warning "kokoro-onnx not installed. Installing..."
        pip3 install kokoro-onnx
    fi

    # Check model files
    MODEL_FILE=$(find "$PROJECT_DIR" -name "kokoro*.onnx" -type f 2>/dev/null | head -1)
    VOICES_FILE=$(find "$PROJECT_DIR" -name "voices*.bin" -type f 2>/dev/null | head -1)

    if [ -z "$MODEL_FILE" ]; then
        print_error "Kokoro model file (kokoro*.onnx) not found in $PROJECT_DIR"
        echo "Download from: https://github.com/thewh1teagle/kokoro-onnx/releases"
        exit 1
    fi

    if [ -z "$VOICES_FILE" ]; then
        print_error "Voices file (voices*.bin) not found in $PROJECT_DIR"
        echo "Download from: https://github.com/thewh1teagle/kokoro-onnx/releases"
        exit 1
    fi

    print_status "Found model: $MODEL_FILE"
    print_status "Found voices: $VOICES_FILE"
}

# Start server
start_server() {
    local daemon_mode=$1

    if check_running; then
        print_warning "Kokoro server is already running (PID: $(cat "$PID_FILE"))"
        echo "Use '$0 stop' to stop it first"
        exit 0
    fi

    check_dependencies

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                 Starting Kokoro TTS Server                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$daemon_mode" = "true" ]; then
        print_status "Starting server in background..."
        nohup python3 "$SERVER_SCRIPT" --model-dir "$PROJECT_DIR" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        sleep 2

        if check_running; then
            print_status "Server started (PID: $(cat "$PID_FILE"))"
            print_status "Log file: $LOG_FILE"
            print_status "Server URL: http://localhost:8880"
        else
            print_error "Server failed to start. Check $LOG_FILE for details"
            exit 1
        fi
    else
        print_status "Starting server in foreground (Ctrl+C to stop)..."
        python3 "$SERVER_SCRIPT" --model-dir "$PROJECT_DIR"
    fi
}

# Stop server
stop_server() {
    if check_running; then
        PID=$(cat "$PID_FILE")
        print_status "Stopping Kokoro server (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        rm -f "$PID_FILE"
        print_status "Server stopped"
    else
        print_warning "Kokoro server is not running"
    fi
}

# Show status
show_status() {
    if check_running; then
        PID=$(cat "$PID_FILE")
        print_status "Kokoro server is running (PID: $PID)"

        # Check if it's responding
        if curl -s http://localhost:8880/health > /dev/null 2>&1; then
            print_status "Server is healthy and responding"
        else
            print_warning "Server process exists but not responding yet"
        fi
    else
        print_warning "Kokoro server is not running"
    fi
}

# Show help
show_help() {
    echo "Kokoro TTS Server Control Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start         Start server in foreground (default)"
    echo "  --daemon, -d  Start server in background"
    echo "  stop          Stop background server"
    echo "  restart       Restart background server"
    echo "  status        Show server status"
    echo "  logs          Show server logs (tail -f)"
    echo "  help          Show this help"
    echo ""
}

# Main
case "${1:-start}" in
    start)
        start_server false
        ;;
    --daemon|-d|daemon)
        start_server true
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 1
        start_server true
        ;;
    status)
        show_status
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            print_warning "No log file found"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
