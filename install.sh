#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_URL="https://raw.githubusercontent.com/developerstriker/lua-obfuscator/master"
INSTALL_DIR="/tmp/fxbuild-install"

usage() {
    echo "Usage: curl -sL $BASE_URL/install.sh | bash -s -- <fxmanifest.lua> [options]"
    echo ""
    echo "Options:"
    echo "  --preset <name>    Obfuscation preset (Minify, Weak, Medium, Strong)"
    echo ""
    echo "Example:"
    echo "  curl -sL $BASE_URL/install.sh | bash -s -- myresource/fxmanifest.lua --preset Weak"
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
curl -sL "$BASE_URL/fxbuild.sh" -o fxbuild.sh
chmod +x fxbuild.sh

echo "Downloading src/fxbuild.lua..."
curl -sL "$BASE_URL/src/fxbuild.lua" -o src/fxbuild.lua

echo "Downloading prometheus submodule..."
git clone --depth 1 https://github.com/developerstriker/lua-obfuscator.git tmp_prometheus
mv tmp_prometheus/prometheus .
rm -rf tmp_prometheus

echo -e "${GREEN}Running obfuscation...${NC}"
./fxbuild.sh "$FXMANIFEST" --preset "$PRESET"