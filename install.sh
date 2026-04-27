#!/bin/bash
# v1.5.0 - GitHub API (no cache)

set -e

INSTALL_DIR="/tmp/fxbuild-run"
API="https://api.github.com/repos/developerstriker/lua-obfuscator/contents"

decode() { python -c "import sys,json; import base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())"; }

usage() {
    echo "Usage: curl -sL https://raw.githubusercontent.com/developerstriker/lua-obfuscator/master/install.sh | bash -s -- <fxmanifest> [opts]"
    exit 1
}

[ $# -eq 0 ] && usage

FXMANIFEST="$1"; shift
PRESET="Minify"
while [ $# -gt 0 ]; do
    case "$1" in --preset|--p) PRESET="$2"; shift 2 ;; *) shift ;; esac
done

[ ! -f "$FXMANIFEST" ] && echo "Error: fxmanifest not found" && exit 1

FXMANIFEST=$(realpath "$FXMANIFEST")
echo "Installing fxbuild..."
rm -rf "$INSTALL_DIR"; mkdir -p "$INSTALL_DIR/src"; cd "$INSTALL_DIR"

echo "Downloading..."
curl -sL "$API/fxbuild.sh" | decode > fxbuild.sh
curl -sL "$API/src/fxbuild.lua" | decode > src/fxbuild.lua
chmod +x fxbuild.sh

echo "Downloading prometheus..."
git clone --depth 1 https://github.com/prometheus-lua/Prometheus.git prometheus

echo "Running..."
./fxbuild.sh "$FXMANIFEST" --preset "$PRESET"
