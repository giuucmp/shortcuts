#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
checks="$PWD/.build/packagedchecks"
export CLANG_MODULE_CACHE_PATH="$checks/module-cache"
args=(--build-system native --disable-sandbox --scratch-path "$checks" --cache-path "$checks/cache")
swift build "${args[@]}" --product CoreChecks
bin=$(swift build "${args[@]}" --show-bin-path)
resource="$bin/Scorciatoie_ShortcutCore.bundle"
backup="$resource.probe-backup"
[[ ! -e "$backup" ]] || { echo "Stale probe backup: $backup" >&2; exit 1; }
app="$checks/ResourceChecks.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/CoreChecks" "$app/Contents/MacOS/CoreChecks"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.scorciatoie.resourcechecks</string>
<key>CFBundleExecutable</key><string>CoreChecks</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
./scripts/copy-resources.sh "$resource" "$app"
mv "$resource" "$backup"
trap 'mv "$backup" "$resource"' EXIT
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
# Foundation-only executable: no NSApplication, windows or event monitors.
# The original SwiftPM bundle is unavailable, proving this is not a build-path fallback.
"$app/Contents/MacOS/CoreChecks"
# Verify the same packaging operation also accepts the structured bundle format.
structured="$checks/StructuredResources.bundle"
rm -rf "$structured"
mkdir -p "$structured"
ditto "$app/Contents/Resources/Scorciatoie_ShortcutCore.bundle" "$structured"
./scripts/copy-resources.sh "$structured" "$app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/CoreChecks"
echo "PASS: installed resource lookup and signature with both bundle layouts"
