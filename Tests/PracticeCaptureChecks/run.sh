#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
checks_dir="$repo_dir/.build/practicechecks"
mkdir -p "$checks_dir/Sources/NativePracticeChecks"
cp "$repo_dir/Sources/Scorciatoie/PracticeKeyCapture.swift" \
   "$repo_dir/Sources/Scorciatoie/HeldModifiers.swift" \
   "$repo_dir/Tests/PracticeCaptureChecks/Checks.swift" \
   "$checks_dir/Sources/NativePracticeChecks/"
cat > "$checks_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"NativePracticeChecks",platforms:[.macOS(.v13)],dependencies:[.package(name:"Scorciatoie",path:"../..")],targets:[.executableTarget(name:"NativePracticeChecks",dependencies:[.product(name:"ShortcutCore",package:"Scorciatoie")])])
PACKAGE
export CLANG_MODULE_CACHE_PATH="$checks_dir/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$checks_dir/module-cache"
swift run --disable-sandbox --cache-path "$checks_dir/cache" --package-path "$checks_dir" NativePracticeChecks
