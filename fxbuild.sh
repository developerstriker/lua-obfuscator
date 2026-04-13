#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$DIR"

if [ ! -d "prometheus" ]; then
    echo "Cloning prometheus submodule..."
    git submodule update --init --recursive
fi

luajit "$DIR/src/fxbuild.lua" "$@"