# Installed resource checks

Run `./Tests/PackagedResourcesChecks/run.sh` on macOS with the documented build toolchain.

This packages the Foundation-only core test executable into a temporary app bundle under `.build/packagedchecks`, using the production resource-copy script. It temporarily moves the original SwiftPM resource bundle, signs and verifies the packaged probe, then runs the full core checks from that bundle. It repeats with a structured resource bundle to cover both SwiftPM layouts. The original is restored on exit.

No `NSApplication`, windows, Accessibility access, or global keyboard events are involved. The actual Scorciatoie app is never started. A pass proves that installed resource lookup works independently of the build machine's absolute path.
