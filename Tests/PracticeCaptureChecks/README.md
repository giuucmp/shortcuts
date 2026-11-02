# Native keyboard practice checks

Run on macOS 13 or later with Swift 5.9 or later:

```sh
./Tests/PracticeCaptureChecks/run.sh
```

The script creates its temporary package and caches under `.build/practicechecks`, copies the current production `PracticeKeyCapture.swift` and `HeldModifiers.swift`, and imports the real `ShortcutCore` SwiftPM product. No private paths, third-party packages, credentials, application installation, or Accessibility permission are required.

The executable keeps its AppKit activation policy prohibited and never orders or displays its window. It sends synthetic events directly to its own `NSWindow`/`NSView`; it does not post events globally, install monitors or taps, or launch Scorciatoie. Application-active and key-window getters are simulated only inside the test process, so real responder routing can be checked without interrupting the foreground app.

Checks cover explicit arming, Cmd+Q/Cmd+W consumption through both key-equivalent and key-down paths, preservation and rejection of key repeats, modifier/key-release feedback, Fn/Delete and Fn/Return translations, responder blur, Stop, window/app deactivation, and restoration of normal menu/next-responder delivery outside capture.

This verifies production responder behavior under simulated focus. It does not prove OS-level event dispatch or interception of user-defined global shortcuts. The fixture never executes reserved system shortcuts. If an outer sandbox prevents AppKit from reporting its activation policy, the command exits with status 2; run it directly from Terminal instead.
