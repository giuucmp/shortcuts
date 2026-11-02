#!/bin/bash
set -euo pipefail
[[ $# == 2 && "$2" == *.app ]] || { echo "Usage: copy-resources.sh SOURCE_BUNDLE DEST.app" >&2; exit 1; }
# Normalize both SwiftPM resource formats into a standard macOS resource bundle.
# Native SwiftPM emits a flat folder without Info.plist; Swift Build emits a
# complete .bundle. Never put data bundles in the executable-only MacOS folder.
resourceName="Scorciatoie_ShortcutCore.bundle"
resource="$1"
dest="$2"
[[ -d "$resource" ]] || { echo "Missing SwiftPM resources: $resource" >&2; exit 1; }
resourceDest="$dest/Contents/Resources/$resourceName"
rm -rf "$resourceDest" "$dest/Contents/MacOS/$resourceName"
if [[ -f "$resource/Contents/Info.plist" ]]; then
  ditto "$resource" "$resourceDest"
else
  mkdir -p "$resourceDest/Contents/Resources"
  ditto "$resource" "$resourceDest/Contents/Resources"
  cat > "$resourceDest/Contents/Info.plist" <<'RESOURCE_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>it.giuseppecampo.Scorciatoie.resources</string>
<key>CFBundleName</key><string>Scorciatoie_ShortcutCore</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
</dict></plist>
RESOURCE_PLIST
fi
