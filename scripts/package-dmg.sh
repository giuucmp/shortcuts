#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-dist/Shortcuts.app}"
output="${2:-dist/Shortcuts-0.3.2-universal.dmg}"
[[ -d "$app" ]] || { echo "Build the app first: UNIVERSAL=1 ./scripts/build-app.sh" >&2; exit 1; }
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
stage=$(mktemp -d "${TMPDIR:-/tmp}/shortcuts-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Shortcuts.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/READ ME - LEGGIMI.txt" <<'TEXT'
SHORTCUTS 0.3.2

ENGLISH
1. Drag Shortcuts to Applications, then open it from Applications.
2. This release is not Developer ID signed or notarized. If macOS blocks it,
   open System Settings > Privacy & Security > Open Anyway, then confirm.
3. Enable Shortcuts in Privacy & Security > Accessibility.
4. Hold Command, Option, Control, Shift or Fn in another app. Release to hide.
Click the Command icon in the menu bar for settings; right-click for Studio.
Language: Settings > Appearance > Language. Quit before replacing an older copy.
Updating from Scorciatoie? Remove the old app after installing Shortcuts.
Preferences and learning progress use the same local storage.

ITALIANO
1. Trascina Shortcuts in Applicazioni, poi aprila da Applicazioni.
2. Questa release non è firmata con Developer ID né notarizzata. Se macOS
   la blocca: Impostazioni di Sistema > Privacy e sicurezza > Apri comunque.
3. Abilita Shortcuts in Privacy e sicurezza > Accessibilità.
4. Tieni premuto Command, Option, Control, Shift o Fn in un'altra app.
   Rilascia i tasti per nascondere il pannello.
Clic sull'icona Command nella barra dei menu: impostazioni. Clic destro: Studio.
Lingua: Impostazioni > Aspetto > Lingua. Chiudi la vecchia copia prima di sostituirla.
Aggiorni da Scorciatoie? Rimuovi la vecchia app dopo aver installato Shortcuts.
Preferenze e progressi usano gli stessi salvataggi locali.

Source / Sorgenti: https://github.com/giuucmp/shortcuts
Guide / Guida: https://giuucmp.github.io/shortcuts/
TEXT
hdiutil create -quiet -volname Shortcuts -srcfolder "$stage" -format UDZO "$output"
hdiutil verify "$output"
shasum -a 256 "$output"
