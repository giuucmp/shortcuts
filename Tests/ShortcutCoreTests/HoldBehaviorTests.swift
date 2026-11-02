import ShortcutCore

func checkHoldBehavior() {
    for modifier in [Modifiers.command,.option,.control,.shift,.function] {
        var session=ModifierSession()
        session.update(modifier,at:0)
        session.tick(at:1)
        XCTAssertTrue(session.canPresent(physicallyHeld:modifier))
        // A late callback cannot show stale content after physical release,
        // even before a flagsChanged event has reached the app.
        XCTAssertFalse(session.canPresent(physicallyHeld:[]))
        session.reconcileHeldModifiers([],at:1.01)
        XCTAssertFalse(session.visible)
        XCTAssertTrue(session.modifiers.isEmpty)
        XCTAssertEqual(session.deadline,nil)
        session.tick(at:20)
        XCTAssertFalse(session.visible)
    }
    var pending=ModifierSession()
    pending.update(.command,at:0)
    pending.reconcileHeldModifiers([],at:0.1)
    pending.tick(at:1)
    XCTAssertFalse(pending.visible)
    // Polling is a release safeguard, never an alternative way to open a panel.
    pending.reconcileHeldModifiers(.command,at:2)
    pending.tick(at:3)
    XCTAssertFalse(pending.visible)
    XCTAssertEqual(pending.deadline,nil)

    var progressive=ModifierSession()
    progressive.update([.command,.shift],at:0)
    progressive.tick(at:1)
    progressive.reconcileHeldModifiers(.command,at:1.1)
    XCTAssertEqual(progressive.modifiers,.command)
    XCTAssertTrue(progressive.canPresent(physicallyHeld:.command))
    // A function flag synthesized for an arrow must not become a new trigger.
    progressive.reconcileHeldModifiers([.command,.function],at:1.2)
    XCTAssertEqual(progressive.modifiers,.command)
    progressive.pressKey()
    progressive.reconcileHeldModifiers(.command,at:1.3)
    progressive.tick(at:10)
    XCTAssertFalse(progressive.visible)
    XCTAssertFalse(progressive.canPresent(physicallyHeld:.command))
    progressive.reconcileHeldModifiers([],at:11)
    progressive.update(.option,at:12)
    progressive.tick(at:13)
    XCTAssertTrue(progressive.canPresent(physicallyHeld:.option))
    progressive.reconcileHeldModifiers(.control,at:14)
    XCTAssertFalse(progressive.visible)
    XCTAssertTrue(progressive.modifiers.isEmpty)
}
