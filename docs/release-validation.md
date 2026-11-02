# Release validation — 0.3.0

- Core behavior, catalog integrity, localization completeness, format arguments, language preference order, saved identities and keyboard matcher: 12,954 assertions passed.
- Python key parser and purpose grouping: 11 tests passed.
- Native AppKit practice responder: 53 assertions passed with an offscreen window and simulated active/key-window getters. No events were sent to other apps.
- Production UI rendered offscreen in English and Italian: panel, practice and settings; no user desktop content included.
- Static website exercised in Microsoft Edge at desktop and mobile widths in both languages: images loaded, no horizontal overflow, modifier filtering, empty state, disclosures and keyboard focus.
- Native glass and secondary-label contrast: 41 assertions passed. Six dark preview renders were pixel-identical before and after the light-only contrast correction.
- Universal app contains arm64 and x86_64 executables, with macOS 13 deployment targets; ad-hoc signature verified. Built with macOS 27.2 SDK/Swift 6.4.2.

## Reproduce

```sh
./scripts/check.sh
python3 scripts/test_key_parser.py
python3 scripts/test_category_classifier.py
./Tests/PracticeCaptureChecks/run.sh
UNIVERSAL=1 ./scripts/build-app.sh
lipo -archs dist/Scorciatoie.app/Contents/MacOS/Scorciatoie
codesign --verify --deep --strict dist/Scorciatoie.app
./scripts/package-dmg.sh
```

Native glass checks require macOS 26+ and GPU access: `./scripts/check-glass.sh`.

The checks do not establish complete coverage of every app, OS-level shortcut dispatch in every context, or runtime compatibility on every older macOS and Intel configuration. No Developer ID certificate or notarization was used. Keyboard practice excludes known system-reserved shortcuts; custom global bindings may still take precedence.
