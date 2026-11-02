import Foundation
import ShortcutCore

func checkContextualShortcuts() throws {
    let catalog=try Catalog.loadBundled()
    let codex=catalog.records(for:"codex")
    let chat=ActiveContext(area:.text,hasWindow:true,hasTextSelection:false)
    let terminal=ActiveContext(area:.terminal,hasWindow:true)
    let browser=ActiveContext(area:.browser,hasWindow:true)
    func titles(_ context:ActiveContext)->[String] {ContextualShortcuts.visible(codex,in:context).map(\.title)}
    XCTAssertFalse(titles(chat).contains{$0.hasPrefix("Clear terminal")})
    XCTAssertFalse(titles(ActiveContext()).contains{$0.hasPrefix("Clear terminal")},"Focus-only commands require positive evidence")
    XCTAssertTrue(titles(terminal).contains{$0.hasPrefix("Clear terminal")})
    XCTAssertTrue(titles(chat).contains{$0.hasPrefix("Toggle terminal")},"Opening a terminal does not require it to be open")
    XCTAssertFalse(titles(chat).contains{$0.hasPrefix("Reload browser page")})
    XCTAssertTrue(titles(browser).contains{$0.hasPrefix("Reload browser page")})
    XCTAssertTrue(titles(chat).contains{$0.hasPrefix("Open browser tab")},"Availability isn't the same as focus")
    XCTAssertTrue(titles(chat).contains{$0.contains("When voice chat is available")},"Unknown internal conditions remain labelled")
    XCTAssertEqual(ContextualShortcuts.visible(codex,in:chat).filter(\.isSystem).count,codex.filter(\.isSystem).count)

    XCTAssertEqual(WhenCondition.evaluate("terminalFocus && featureFlag",context:chat),.no)
    XCTAssertEqual(WhenCondition.evaluate("terminalFocus || editorTextFocus",context:ActiveContext(area:.editor)),.yes)
    XCTAssertEqual(WhenCondition.evaluate("!terminalFocus && (inputFocus || editorTextFocus)",context:chat),.yes)
    XCTAssertEqual(WhenCondition.evaluate("!terminalFocus",context:ActiveContext()),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("editorHasSelection",context:ActiveContext(area:.editor,hasTextSelection:false)),.no)
    XCTAssertEqual(WhenCondition.evaluate("someMode == special",context:chat),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("terminalFocus && someMode == special",context:chat),.no)
    XCTAssertEqual(WhenCondition.evaluate("terminalFocus || someMode != special",context:terminal),.yes)
    XCTAssertEqual(WhenCondition.evaluate("editorTextFocus && someMode == special",context:ActiveContext(area:.editor)),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("  isMac  ",context:chat),.yes)
    XCTAssertEqual(WhenCondition.evaluate(String(repeating:"!",count:9000)+"isMac",context:chat),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("terminalFocus & inputFocus",context:terminal),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("terminalFocus ||",context:terminal),.unknown)
    XCTAssertEqual(WhenCondition.evaluate("isMac && !isWindows",context:chat),.yes)

    var copy=Shortcut(id:"copy",profile:"pages",title:"Copy",category:"File",strokes:[KeyStroke(key:"C",modifiers:.command)],source:.catalog)
    var menu=copy;menu.id="menu";menu.title="Copia";menu.source = .menu;menu.enabled=false
    let visible=ContextualShortcuts.visible(ShortcutFilter.forDisplay([copy,menu]),in:chat)
    XCTAssertTrue(visible.isEmpty,"A disabled menu command must not resurrect through its translated catalog fallback")
    copy.context="Con testo selezionato"
    XCTAssertEqual(ContextualShortcuts.applicability(copy,in:chat),.no)
    XCTAssertEqual(ContextualShortcuts.applicability(copy,in:ActiveContext(area:.text,hasTextSelection:true)),.yes)
    copy.context="Campo testo compatibile"
    XCTAssertEqual(ContextualShortcuts.applicability(copy,in:terminal),.no)
    copy.context="editorTextFocus && customExtensionMode";copy.source = .extensionBinding
    XCTAssertEqual(ContextualShortcuts.applicability(copy,in:terminal),.no)
    XCTAssertEqual(ContextualShortcuts.applicability(copy,in:ActiveContext(area:.editor)),.unknown)

    func area(_ bundle:String,_ nodes:FocusMetadata...)->FocusArea {FocusClassifier.area(bundle:bundle,path:nodes)}
    XCTAssertEqual(area("com.openai.codex",FocusMetadata(role:"AXTextArea"),FocusMetadata(role:"AXWebArea")),.text)
    XCTAssertEqual(area("com.openai.codex",FocusMetadata(role:"AXTextArea",identifier:"xterm-helper-textarea")),.terminal)
    XCTAssertEqual(area("com.openai.codex",FocusMetadata(role:"AXTextArea",description:"Terminal input")),.terminal)
    XCTAssertEqual(area("com.microsoft.VSCode",FocusMetadata(role:"AXTextArea",description:"Editor content;Press Alt+F1 for Accessibility Options.")),.editor)
    XCTAssertTrue(area("com.microsoft.VSCode",FocusMetadata(role:"AXTextArea")) == .unknown,"An editor without identifying metadata must not be mistaken for an ordinary input")
    XCTAssertEqual(area("com.microsoft.VSCode",FocusMetadata(role:"AXTextField",identifier:"terminal-find-input"),FocusMetadata(role:"AXGroup",identifier:"terminal")),.text)
    XCTAssertEqual(area("com.apple.Terminal",FocusMetadata(role:"AXTextArea")),.terminal)
    XCTAssertEqual(area("com.apple.Terminal",FocusMetadata(role:"AXTextField",identifier:"search")),.text)
    XCTAssertEqual(area("com.microsoft.edgemac",FocusMetadata(role:"AXLink"),FocusMetadata(role:"AXWebArea")),.browser)
    XCTAssertEqual(area("com.openai.codex",FocusMetadata(role:"AXLink"),FocusMetadata(role:"AXWebArea")),.other)
    XCTAssertEqual(area("com.openai.codex",FocusMetadata(role:"AXButton",description:"Terminal")),.other)
    XCTAssertEqual(FocusClassifier.area(bundle:"unknown",path:[]),.unknown)

    let claude=catalog.records(for:"claude").filter{!$0.isSystem}
    XCTAssertFalse(claude.isEmpty,"Claude desktop must not depend on a CLI catalog or a successful menu scan")
    XCTAssertTrue(claude.contains{$0.title == "Nuova sessione" && $0.strokes == [KeyStroke(key:"N",modifiers:.command)]})
    XCTAssertTrue(claude.contains{$0.title == "Mostra scorciatoie" && $0.strokes == [KeyStroke(key:"/",modifiers:.command)]})
    XCTAssertTrue(claude.filter{$0.title == "Nuova sessione" || $0.title == "Chiudi sessione"}.allSatisfy{ShortcutPresentation.group($0) == "Schede e finestre"})
    XCTAssertTrue(claude.filter{$0.title == "Chiudi riquadro attivo"}.allSatisfy{ShortcutPresentation.title($0) == "Chiudi riquadro attivo"})
    let knownChat=ContextualShortcuts.visible(claude,in:ActiveContext(area:.text,claudeSection:"Chat"))
    XCTAssertFalse(knownChat.contains{$0.title == "Nuova sessione"})
    XCTAssertTrue(knownChat.contains{$0.title == "Impostazioni"})
    XCTAssertTrue(ContextualShortcuts.visible(claude,in:ActiveContext(area:.text,claudeSection:"Code")).contains{$0.title == "Nuova sessione"})
    XCTAssertTrue(ContextualShortcuts.visible(claude,in:chat).contains{$0.title == "Nuova sessione"},"An unexposed Code/Chat tab must keep the documented, labelled fallback")
    XCTAssertTrue(catalog.records(for:"claude-code").contains{$0.actionID == "app:interrupt"})
    XCTAssertFalse(claude.contains{$0.actionID == "app:interrupt"},"CLI shortcuts must not leak into desktop")
    XCTAssertTrue(try JSONDecoder().decode(ShortcutOptions.self,from:Data("{}".utf8)).contextualFiltering)
    let supplements=ContextualShortcuts.textInputSupplements(catalog.shortcuts,profile:"codex",existing:codex,context:chat)
    XCTAssertFalse(supplements.contains{$0.title == "Salva documento" || $0.title == "Stampa documento"},"Focusing a prompt must not invent document actions")
    XCTAssertTrue(supplements.contains{$0.title == "Inizio riga"},"The same binding may belong to a browser command in a different context")
    XCTAssertTrue(ContextualShortcuts.textInputSupplements(catalog.shortcuts,profile:"codex",existing:codex,context:terminal).isEmpty)
    let claudeText=ContextualShortcuts.textInputSupplements(catalog.shortcuts,profile:"claude",existing:claude,context:chat)
    XCTAssertFalse(claudeText.contains{$0.title == "Copia testo"},"Do not duplicate an app's own copy command with a generic binding")
    var disabledCopy=copy;disabledCopy.context=nil;disabledCopy.enabled=false
    XCTAssertFalse(ContextualShortcuts.textInputSupplements(catalog.shortcuts,profile:"pages",existing:[disabledCopy],context:chat).contains{$0.title == "Copia testo"})
}
