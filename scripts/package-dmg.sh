#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-dist/Scorciatoie.app}"
output="${2:-dist/Scorciatoie-0.3.1-universal.dmg}"
[[ -d "$app" ]] || { echo "Build the app first: UNIVERSAL=1 ./scripts/build-app.sh" >&2; exit 1; }
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
stage=$(mktemp -d "${TMPDIR:-/tmp}/scorciatoie-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Scorciatoie.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/READ ME - LEGGIMI.txt" <<'TEXT'
SCORCIATOIE 0.3.1

ENGLISH
1. Drag Scorciatoie to Applications, then open it from Applications.
2. This release is not Developer ID signed or notarized. If macOS blocks it,
   open System Settings > Privacy & Security > Open Anyway, then confirm.
3. Enable Scorciatoie in Privacy & Security > Accessibility.
4. Hold Command, Option, Control, Shift or Fn in another app. Release to hide.
Click the Command icon in the menu bar for settings; right-click for Studio.
Language: Settings > Appearance > Language. Quit before replacing an older copy.

ITALIANO
1. Trascina Scorciatoie in Applicazioni, poi aprila da Applicazioni.
2. Questa release non è firmata con Developer ID né notarizzata. Se macOS
   la blocca: Impostazioni di Sistema > Privacy e sicurezza > Apri comunque.
3. Abilita Scorciatoie in Privacy e sicurezza > Accessibilità.
4. Tieni premuto Command, Option, Control, Shift o Fn in un'altra app.
   Rilascia i tasti per nascondere il pannello.
Clic sull'icona Command nella barra dei menu: impostazioni. Clic destro: Studio.
Lingua: Impostazioni > Aspetto > Lingua. Chiudi la vecchia copia prima di sostituirla.

Source / Sorgenti: https://github.com/giuucmp/scorciatoie
Guide / Guida: https://giuucmp.github.io/scorciatoie/
TEXT
hdiutil create -quiet -volname Scorciatoie -srcfolder "$stage" -format UDZO "$output"
hdiutil verify "$output"
shasum -a 256 "$output"
