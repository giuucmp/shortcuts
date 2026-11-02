import Foundation
import ShortcutCore
final class CoreTests {
    func item(_ id: String, _ modifiers: Modifiers, profile: String = "finder", key: String = "N", context: String? = nil) -> Shortcut {
        Shortcut(id: id, profile: profile, title: id, category: "File", strokes: [KeyStroke(key: key, modifiers: modifiers)], context: context, source: .catalog, sourceURL: "https://support.apple.com/en-us/102650")
    }
    func testAllModifiersAndSuperset() {
        let all = [item("cmd", .command), item("shift", [.command, .shift]), item("option", .option), item("control", .control), item("fn", .function, key: "Delete")]
        XCTAssertEqual(ShortcutFilter.match(all, modifiers: .command).map(\.id), ["cmd", "shift"])
        XCTAssertEqual(ShortcutFilter.match(all, modifiers: [.command, .shift]).map(\.id), ["shift"])
        XCTAssertEqual(ShortcutFilter.match(all, modifiers: .option).map(\.id), ["option"])
        XCTAssertEqual(ShortcutFilter.match(all, modifiers: .control).map(\.id), ["control"])
        XCTAssertEqual(ShortcutFilter.match(all, modifiers: .function).map(\.id), ["fn"])
    }
    func testSystemIncludedAndAppsIsolated() {
        let all = [item("switch", .command, profile: "system", key: "Tab"), item("new", .command), item("word", .command, profile: "word")]
        XCTAssertEqual(ShortcutFilter.forProfile(all, profile: "finder").map(\.id), ["switch", "new"])
    }
    func testOptionControlShiftAndFnCanStart() {
        for modifier in [Modifiers.option, .control, .shift, .function] {
            var session = ModifierSession()
            session.update(modifier, at: 0)
            XCTAssertFalse(session.visible)
            session.tick(at: 1)
            XCTAssertTrue(session.visible, "\(modifier)")
            session.update([], at: 1.1)
            XCTAssertFalse(session.visible)
        }
    }
    func testTypingCancelsAndDoesNotReopenUntilRelease() {
        var session = ModifierSession()
        session.update(.shift, at: 0)
        session.pressKey()
        session.tick(at: 1)
        XCTAssertFalse(session.visible)
        session.update([.shift,.command], at: 2)
        session.tick(at: 3)
        XCTAssertFalse(session.visible)
        session.update([], at: 4)
        session.update(.control, at: 5)
        session.tick(at: 6)
        XCTAssertTrue(session.visible)
    }
    func testProgressiveModifierDoesNotRestartDelay() {
        var s = ModifierSession()
        s.update(.command, at: 0)
        s.update([.command,.shift], at: 0.2)
        s.tick(at: 0.36)
        XCTAssertTrue(s.visible)
        s.update(.shift, at: 0.4)
        XCTAssertTrue(s.visible)
    }
    func testContextPreservedAndExactDuplicatesRemoved() {
        let a = item("a", .control, key: "A", context: "Editor")
        var b = a; b.id = "b"; b.context = "Terminale"
        XCTAssertEqual(ShortcutFilter.unique([a,a,b]).count, 2)
    }
    func testAXModifiersAreNotNSEventFlags() {
        XCTAssertEqual(Modifiers.accessibility(0), .command)
        XCTAssertEqual(Modifiers.accessibility(2 | 8), .option)
        XCTAssertEqual(Modifiers.accessibility(4 | 8), .control)
        XCTAssertEqual(Modifiers.accessibility(1 | 8), .shift)
    }
    func testStaleScanCannotReplaceCurrentApp() {
        var gate = ScanGeneration()
        let first = gate.advance()
        let second = gate.advance()
        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))
    }
}
