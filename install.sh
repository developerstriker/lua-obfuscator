#!/bin/bash
# v1.3.0 - FINAL with API - no cache

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="https://api.github.com/repos/developerstriker/lua-obfuscator/contents"
INSTALL_DIR="/tmp/fxbuild-run"

usage() {
    echo "Usage: curl -sL https://raw.githubusercontent.com/developerstriker/lua-obfuscator/master/install.sh | bash -s -- <fxmanifest.lua> [options]"
    echo ""
    echo "Options:"
    echo "  --preset <name>    Obfuscation preset (Minify, Weak, Medium, Strong)"
    echo ""
    echo "Example:"
    echo "  curl -sL https://raw.githubusercontent.com/developerstriker/lua-obfuscator/master/install.sh | bash -s -- myresource/fxmanifest.lua --preset Weak"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

FXMANIFEST="$1"
shift

PRESET="Minify"
while [ $# -gt 0 ]; do
    case "$1" in
        --preset|--p)
            PRESET="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ ! -f "$FXMANIFEST" ]; then
    echo -e "${RED}Error: fxmanifest.lua not found: $FXMANIFEST${NC}"
    exit 1
fi

FXMANIFEST=$(realpath "$FXMANIFEST")

echo -e "${YELLOW}Installing fxbuild...${NC}"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/src"
cd "$INSTALL_DIR"

echo "Downloading fxbuild.sh..."
curl -sL "$API_URL/fxbuild.sh" | python3 -c "import sys,json; print(json.load(sys.stdin)['content'], end='')" | base64 -d > fxbuild.sh
chmod +x fxbuild.sh

echo "Downloading src/fxbuild.lua..."
curl -sL "$API_URL/src/fxbuild.lua" | python3 -c "import sys,json; print(json.load(sys.stdin)['content'], end='')" | base64 -d > src/fxbuild.lua

echo "Downloading prometheus..."
git clone --depth 1 https://github.com/prometheus-lua/Prometheus.git prometheus

echo -e "${GREEN}Running obfuscation...${NC}"
./fxbuild.sh "$FXMANIFEST" --preset "$PRESET"