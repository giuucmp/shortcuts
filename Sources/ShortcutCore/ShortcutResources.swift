import Foundation

/// SwiftPM's native and Swift Build backends generate different bundle lookup
/// code. Packaged macOS apps always keep resources in Contents/Resources.
/// Keep SwiftPM's accessor as the fallback for command-line tools and tests.
enum ShortcutResources {
    static let bundle:Bundle = {
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Scorciatoie_ShortcutCore.bundle"),
           let bundle=Bundle(url:url) {return bundle}
        return Bundle.module
    }()
}
