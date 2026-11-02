#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
configuration="${CONFIGURATION:-release}"
dest="${1:-dist/Scorciatoie.app}"
args=(--disable-sandbox --cache-path "$PWD/.build/cache" -c "$configuration")
mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Resources"
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  binaries=()
  for arch in arm64 x86_64; do
    swift build "${args[@]}" --arch "$arch" --product Scorciatoie
    bin=$(swift build "${args[@]}" --arch "$arch" --show-bin-path)
    # Recent SwiftPM uses one Products path for all --arch builds. Preserve
    # each executable before the next architecture overwrites that path.
    archBin="$PWD/.build/universal/$arch/Scorciatoie"
    mkdir -p "$(dirname "$archBin")"
    cp "$bin/Scorciatoie" "$archBin"
    binaries+=("$archBin")
  done
  lipo -create "${binaries[@]}" -output "$dest/Contents/MacOS/Scorciatoie"
else
  swift build "${args[@]}" --product Scorciatoie
  bin=$(swift build "${args[@]}" --show-bin-path)
  cp "$bin/Scorciatoie" "$dest/Contents/MacOS/Scorciatoie"
fi
# SwiftPM resolves resources beside the executable or in the main bundle.
for resource in "$bin"/*ShortcutCore*.bundle; do
  if [[ -d "$resource" ]]; then
    ditto "$resource" "$dest/Contents/Resources/$(basename "$resource")"
    ditto "$resource" "$dest/Contents/MacOS/$(basename "$resource")"
  fi
done
cat > "$dest/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Scorciatoie</string>
<key>CFBundleIdentifier</key><string>it.giuseppecampo.Scorciatoie</string>
<key>CFBundleName</key><string>Scorciatoie</string>
<key>CFBundleDisplayName</key><string>Scorciatoie</string>
<key>CFBundleVersion</key><string>9</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>it</string></array>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swift scripts/create-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$dest/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$dest"
codesign --verify --deep --strict "$dest"
echo "Built: $dest"
lipo -archs "$dest/Contents/MacOS/Scorciatoie"
