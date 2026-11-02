// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Scorciatoie", platforms: [.macOS(.v13)],
    products: [.executable(name: "Scorciatoie", targets: ["Scorciatoie"]), .library(name: "ShortcutCore", targets: ["ShortcutCore"])],
    targets: [
        .target(name: "ShortcutCore", resources: [.process("Resources")]),
        .executableTarget(name: "Scorciatoie", dependencies: ["ShortcutCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["ShortcutCore"], path: "Tests/ShortcutCoreTests")
    ]
)
