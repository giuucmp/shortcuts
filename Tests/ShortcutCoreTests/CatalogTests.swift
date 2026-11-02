import Foundation
import ShortcutCore
func checkCatalog() throws {
    let c = try Catalog.loadBundled()
    for p in ["system","finder","word","excel","cursor","vscode","claude-code","codex","codex-cli","grok","vlc"] {
        XCTAssertTrue(c.profiles.contains { $0.id == p }, "Missing \(p)")
    }
    XCTAssertEqual(Set(c.shortcuts.map(\.id)).count,c.shortcuts.count)
    XCTAssertTrue(c.shortcuts.allSatisfy { $0.sourceURL != nil })
    XCTAssertTrue(c.records(for:"grok").contains { $0.profile == "system" && $0.strokes == [KeyStroke(key:"Tab", modifiers:.command)] })
    XCTAssertTrue(c.records(for:"finder").contains { $0.strokes == [KeyStroke(key:"V",modifiers:[.command,.option])] })
    XCTAssertTrue(c.records(for:"vlc").contains { $0.strokes == [KeyStroke(key:"E")] })
    XCTAssertTrue(c.shortcuts.contains { $0.strokes.first?.modifiers == .control })
    XCTAssertTrue(c.shortcuts.contains { $0.strokes.first?.modifiers == .option })
    XCTAssertTrue(c.shortcuts.contains { $0.strokes.first?.modifiers == .function })
    print("Catalog: \(c.profiles.count) profiles, \(c.shortcuts.count) records")
}
