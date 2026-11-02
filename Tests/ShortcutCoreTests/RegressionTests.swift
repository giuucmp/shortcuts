import Foundation
import ShortcutCore
func checkReviewRegressions() throws {
    var item=try Catalog.loadBundled().shortcuts.first{$0.profile=="finder" && $0.title=="Copia"}!
    var live=item;live.id="live-copy";live.source = .menu;live.context=nil;live.enabled=false;live.strokes=[KeyStroke(key:"K",modifiers:[.command,.option])]
    let merged=ShortcutFilter.merge(catalog:[item],actual:[live])
    XCTAssertEqual(merged.count,1)
    XCTAssertEqual(merged[0].enabled,false)
    var contextual=item;contextual.id="table-copy";contextual.context="Solo nella tabella"
    XCTAssertEqual(ShortcutFilter.merge(catalog:[item,contextual],actual:[live]).count,2)
    let deletion=try BindingImport.vscode(Data("[{\"key\":\"delete\",\"command\":\"forward\"},{\"key\":\"backspace\",\"command\":\"backward\"}]".utf8),profile:"vscode")
    XCTAssertEqual(deletion.shortcuts[0].strokes[0].key,"ForwardDelete")
    XCTAssertEqual(deletion.shortcuts[1].strokes[0].key,"Delete")
    let empty=try BindingImport.vscode(Data("[{\"key\":\"ctrl+x\",\"command\":\"\"}]".utf8),profile:"vscode")
    XCTAssertEqual(empty.shortcuts.count,0)
    XCTAssertEqual(empty.removals.count,1)
    item.profile="vscode";item.context=nil;item.actionID="editor.action.clipboardCopyAction"
    let removal=try BindingImport.vscode(Data("[{\"key\":\"cmd+c\",\"command\":\"-editor.action.clipboardCopyAction\",\"when\":\"editorTextFocus\"}]".utf8),profile:"vscode")
    let unresolved=BindingImport.apply([item],report:removal)
    XCTAssertTrue(unresolved[0].note?.contains("Conflitto") ?? false)
    var session=ModifierSession();session.triggers = .command
    session.update(.command,at:0);session.update(.shift,at:0.1);session.tick(at:1)
    XCTAssertFalse(session.visible)
}
