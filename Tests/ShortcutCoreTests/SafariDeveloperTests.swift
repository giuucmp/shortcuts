import Foundation
import ShortcutCore

/// The parent test runner calls this after the developer supplement is built.
func checkSafariDeveloper() throws {
    let catalog = try Catalog.loadBundled()
    let developer = catalog.shortcuts.filter { $0.id.hasPrefix("safari:developer:") }
    let inspector = catalog.shortcuts.filter { $0.id.hasPrefix("safari-inspector:") }
    XCTAssertEqual(developer.count, 20)
    XCTAssertEqual(developer.filter { !$0.strokes.isEmpty }.count, 8)
    XCTAssertEqual(inspector.count, 149)
    XCTAssertEqual(inspector.filter { !$0.strokes.isEmpty }.count, 147)
    XCTAssertEqual(Set((developer + inspector).map(\.id)).count, developer.count + inspector.count)

    func has(_ rows: [Shortcut], _ action: String, _ key: String, _ modifiers: Modifiers) -> Bool {
        rows.contains { $0.actionID == action && $0.strokes == [KeyStroke(key: key, modifiers: modifiers)] }
    }
    // Responsive Design uses Control; Option+Command+R reloads from origin.
    XCTAssertTrue(has(developer, "safari:responsive-design", "R", [.control, .command]))
    XCTAssertFalse(has(developer, "safari:responsive-design", "R", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:empty-caches", "E", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:web-inspector", "I", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:javascript-console", "C", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:page-source", "U", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:page-resources", "A", [.option, .command]))
    XCTAssertTrue(has(developer, "safari:timeline-recording", "T", [.option, .shift, .command]))
    XCTAssertTrue(has(developer, "safari:element-selection", "C", [.shift, .command]))
    XCTAssertTrue(has(inspector, "safari-inspector:reload-origin", "R", [.option, .command]))
    XCTAssertTrue(has(inspector, "safari-inspector:debugger-over", "F6", []))
    XCTAssertTrue(has(inspector, "safari-inspector:debugger-into", "F7", []))
    XCTAssertTrue(has(inspector, "safari-inspector:debugger-out", "F8", []))
    XCTAssertTrue(has(inspector, "safari-inspector:debugger-step", "F9", []))
    // Alternative shortcuts are separate rows, never multi-stroke sequences.
    XCTAssertTrue(inspector.allSatisfy { $0.strokes.count <= 1 })
    XCTAssertTrue(has(inspector, "safari-inspector:open-resource", "P", .command))
    XCTAssertTrue(has(inspector, "safari-inspector:open-resource", "O", [.shift, .command]))

    // Writing direction changes tab navigation, while numeric editing differs
    // between the text editor and the CSS Styles panel.
    XCTAssertTrue(has(inspector, "safari-inspector:tab-next-ltr", "Tab", .control))
    XCTAssertTrue(has(inspector, "safari-inspector:tab-next-rtl", "Tab", [.control, .shift]))
    XCTAssertTrue(has(inspector, "safari-inspector:editor-number-1", "Up", .option))
    XCTAssertTrue(has(inspector, "safari-inspector:styles-number-0.1", "Up", .option))

    let child = catalog.profiles.first { $0.id == "safari-inspector" }
    XCTAssertEqual(child?.parent, "safari")
    XCTAssertTrue(child?.bundleIDs.isEmpty == true)
    XCTAssertEqual(catalog.profile(for: "com.apple.Safari")?.id, "safari")
    XCTAssertFalse(catalog.records(for: "safari").contains { $0.profile == "safari-inspector" })
    XCTAssertFalse(catalog.records(for: "finder").contains { $0.id.hasPrefix("safari:developer:") })
    XCTAssertTrue(catalog.records(for: "safari-inspector").contains { $0.actionID == "safari:responsive-design" })

    XCTAssertTrue(developer.allSatisfy {
        $0.profile == "safari" && $0.category == "Sviluppare e debuggare" &&
        $0.context?.contains("menu Sviluppo attivo") == true && $0.enabled == nil
    })
    XCTAssertTrue(inspector.allSatisfy {
        $0.profile == "safari-inspector" && $0.category == "Sviluppare e debuggare" &&
        $0.context?.hasPrefix("Web Inspector attivo · ") == true && $0.enabled == nil &&
        $0.sourceURL == "https://webkit.org/web-inspector/keyboard-shortcuts/" &&
        $0.note?.contains("156") == true && $0.note?.contains("non è una verifica completa") == true
    })
    // Space means different things in each of these tabs; context must survive.
    let space = inspector.filter { $0.strokes == [KeyStroke(key: "Space")] }
    XCTAssertTrue(space.contains { $0.actionID == "safari-inspector:timeline-toggle" && $0.context?.contains("Timeline") == true })
    XCTAssertTrue(space.contains { $0.actionID == "safari-inspector:graphics-toggle" && $0.context?.contains("Grafica") == true })
    XCTAssertTrue(space.contains { $0.actionID == "safari-inspector:audit-toggle" && $0.context?.contains("Audit") == true })
    XCTAssertTrue(inspector.filter { $0.actionID?.hasPrefix("safari-inspector:debugger-") == true && $0.actionID != "safari-inspector:debugger-breakpoints" && $0.actionID != "safari-inspector:debugger-pause" }.allSatisfy { $0.context?.contains("in pausa") == true })
    XCTAssertTrue(developer.filter { $0.strokes.isEmpty }.allSatisfy { $0.rawBinding == "Dal menu Sviluppo · nessun tasto documentato" })
    XCTAssertTrue(inspector.filter { $0.strokes.isEmpty }.allSatisfy { $0.rawBinding != nil })

    for row in developer + inspector {
        XCTAssertTrue(row.source == .catalog && row.sourceURL?.hasPrefix("https://") == true)
        for text in [row.title, row.context, row.section, row.note, row.rawBinding].compactMap({ $0 }) {
            XCTAssertTrue(L10n.hasTranslation(text), "Missing Safari localization: \(text)")
            XCTAssertFalse(L10n.text(text, language: .en).isEmpty)
        }
    }
    XCTAssertEqual(L10n.text("Svuota le cache", language: .en), "Empty caches")
    XCTAssertEqual(L10n.text("Attiva o disattiva la modalità di progettazione adattiva", language: .en), "Toggle Responsive Design Mode")
    print("Safari developer: \(developer.count) menu entries; \(inspector.count) scoped inspector bindings/gestures")
}
