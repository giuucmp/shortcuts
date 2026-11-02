# Release validation — 0.3.2

The 0.3.2 release renames the app to **Shortcuts**. Its bundle identifier, preferences domain, saved shortcut identities and menu-bar position identifier are retained. The Swift package/target and resource bundle retain their original internal names.

The behavioral, native UI and contrast checks were completed for 0.3.1. For 0.3.2, core/localization checks, installed-resource probes, universal packaging and website verification were repeated. The brand name is kept out of the translation lookup so it does not override the catalog translation for Apple’s Shortcuts app (Comandi Rapidi in Italian).

- Core behavior, catalog integrity, localization completeness, format arguments, language preference order, saved identities and keyboard matcher: 12,951 assertions passed.
- Python key parser and purpose grouping: 11 tests passed.
- Native AppKit practice responder: 53 assertions passed with an offscreen window and simulated active/key-window getters. No events were sent to other apps.
- Production UI rendered offscreen in English and Italian: panel, practice and settings; no user desktop content included.
- Static website exercised in Microsoft Edge at desktop and mobile widths in both languages: images loaded, no horizontal overflow, modifier filtering, empty state, disclosures and keyboard focus.
- Native glass and secondary-label contrast: 41 assertions passed. Six dark preview renders were pixel-identical before and after the light-only contrast correction.
- Universal app contains arm64 and x86_64 executables, with macOS 13 deployment targets; ad-hoc signature verified. Built with macOS 27.2 SDK/Swift 6.4.2.

- Packaged Foundation-only probe passed all 12,951 core assertions for both flat and structured resource inputs, with the original build bundle temporarily removed.
- Resource bundles are normalized for both SwiftPM build backends and resolved from the installed app’s Contents/Resources.

## Reproduce

```sh
./scripts/check.sh
python3 scripts/test_key_parser.py
python3 scripts/test_category_classifier.py
./Tests/PracticeCaptureChecks/run.sh
UNIVERSAL=1 ./scripts/build-app.sh
lipo -archs dist/Shortcuts.app/Contents/MacOS/Shortcuts
codesign --verify --deep --strict dist/Shortcuts.app
./Tests/PackagedResourcesChecks/run.sh
./scripts/package-dmg.sh
```

Native glass checks require macOS 26+ and GPU access: `./scripts/check-glass.sh`.

The checks do not establish complete coverage of every app, OS-level shortcut dispatch in every context, or runtime compatibility on every older macOS and Intel configuration. No Developer ID certificate or notarization was used. Keyboard practice excludes known system-reserved shortcuts; custom global bindings may still take precedence.
