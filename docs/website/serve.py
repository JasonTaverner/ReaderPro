#!/usr/bin/env python3
"""
Local server for ReaderPro documentation.

Usage:
    python docs/website/serve.py

Opens http://localhost:8000/website/ in your default browser.
"""
import http.server
import socketserver
import os
import sys
import webbrowser

PORT = 8000

# Serve from docs/ directory (parent of website/) so both
# website assets and markdown files are accessible
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DOCS_DIR = os.path.dirname(SCRIPT_DIR)
os.chdir(DOCS_DIR)

Handler = http.server.SimpleHTTPRequestHandler
Handler.extensions_map.update({
    '.md': 'text/plain; charset=utf-8',
    '.mermaid': 'text/plain; charset=utf-8',
})

URL = f"http://localhost:{PORT}/website/"

print(f"\n  📖 ReaderPro Documentation Server")
print(f"  ──────────────────────────────────")
print(f"  Local:   {URL}")
print(f"  Root:    {DOCS_DIR}")
print(f"  Ctrl+C to stop\n")

webbrowser.open(URL)

try:
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n  Server stopped.")
    sys.exit(0)
except OSError as e:
    if "Address already in use" in str(e):
        print(f"\n  ⚠️  Port {PORT} already in use. Try:")
        print(f"     python docs/website/serve.py  (wait a moment)")
        print(f"     or open {URL} directly\n")
    else:
        raise
