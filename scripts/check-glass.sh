#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/glass-checks
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swiftc Sources/Scorciatoie/GlassContrast.swift Sources/Scorciatoie/ShortcutAccent.swift Tests/GlassContrastChecks.swift -o .build/glass-checks/GlassContrastChecks
.build/glass-checks/GlassContrastChecks
