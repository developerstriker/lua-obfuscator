#!/bin/bash
# v1.4.0 - Direct commit hash download

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/tmp/fxbuild-run"
COMMIT="8d90fd5b96b991ec0f40852e05de9d2fab6ca398"
RAW_URL="https://raw.githubusercontent.com/developerstriker/lua-obfuscator/$COMMIT"

usage() {
    echo "Usage: curl -sL https://raw.githubusercontent.com/developerstriker/lua-obfuscator/master/install.sh | bash -s -- <fxmanifest.lua> [options]"
    exit 1
}

[ $# -eq 0 ] && usage

FXMANIFEST="$1"
shift

PRESET="Minify"
while [ $# -gt 0 ]; do
    case "$1" in
        --preset|--p)
            PRESET="$2"
            shift 2
            ;;
        *) shift
            ;;
    esac
done

[ ! -f "$FXMANIFEST" ] && echo -e "${RED}Error: fxmanifest not found: $FXMANIFEST${NC}" && exit 1

FXMANIFEST=$(realpath "$FXMANIFEST")

echo -e "${YELLOW}Installing fxbuild...${NC}"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/src"
cd "$INSTALL_DIR"

echo "Downloading..."
curl -sL "$RAW_URL/fxbuild.sh" -o fxbuild.sh
curl -sL "$RAW_URL/src/fxbuild.lua" -o src/fxbuild.lua
chmod +x fxbuild.sh

echo "Downloading prometheus..."
git clone --depth 1 https://github.com/prometheus-lua/Prometheus.git prometheus

echo -e "${GREEN}Running...${NC}"
./fxbuild.sh "$FXMANIFEST" --preset "$PRESET"