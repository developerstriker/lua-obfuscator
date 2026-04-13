#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$DIR"

if [ ! -d "prometheus" ]; then
    echo "Cloning prometheus obfuscator..."
    git clone --depth 1 https://github.com/prometheus-lua/Prometheus.git prometheus
fi

luajit "$DIR/src/fxbuild.lua" "$@"