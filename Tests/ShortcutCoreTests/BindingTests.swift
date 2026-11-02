import Foundation
import ShortcutCore
func checkBindings() throws {
    let source="""
    [ // custom URL must not be treated as a comment
      {"key":"ctrl+k ctrl+s","command":"workbench.action.openGlobalKeybindings","when":"editorTextFocus",},
      {"key":"alt+x","command":"-test.remove"},
      {"key":"shift+tab","command":"test.next","args":{"url":"https://example.com"}}
    ]
    """
    let result=try BindingImport.vscode(Data(source.utf8),profile:"vscode")
    XCTAssertEqual(result.shortcuts.count,2)
    XCTAssertEqual(result.removals.count,1)
    XCTAssertEqual(result.shortcuts[0].strokes.count,2)
    XCTAssertEqual(result.shortcuts[0].strokes[0].modifiers,.control)
    XCTAssertEqual(result.shortcuts[1].strokes[0],KeyStroke(key:"Tab",modifiers:.shift))
    let cc=try BindingImport.claude(Data("{\"bindings\":[{\"context\":\"Chat\",\"bindings\":{\"ctrl+x\":null,\"alt+enter\":\"chat:submit\"}}]}".utf8))
    XCTAssertEqual(cc.removals.count,1)
    XCTAssertEqual(cc.shortcuts[0].strokes,[KeyStroke(key:"Return",modifiers:.option)])
    XCTAssertEqual(KeyBindingParser.parse("cmd++"),[KeyStroke(key:"+",modifiers:.command)])
    XCTAssertEqual(KeyBindingParser.parse("fn+delete"),[KeyStroke(key:"Delete",modifiers:.function)])
    XCTAssertTrue(KeyBindingParser.parse("something-invalid").isEmpty)
    var base=Shortcut(id:"base",profile:"vscode",title:"Remove",category:"Test",strokes:[KeyStroke(key:"X",modifiers:.option)],source:.catalog,actionID:"test.remove")
    XCTAssertFalse(BindingImport.apply([base],report:result).contains{$0.id=="base"})
    base.context="otherFocus"
    var conditional=result;conditional.removals[0].context="editorTextFocus"
    XCTAssertTrue(BindingImport.apply([base],report:conditional).contains{$0.id=="base"})
}
func checkCustomImport() throws {
    let r=try BindingImport.custom(Data("[{\"profile\":\"finder\",\"title\":\"Mio comando\",\"keys\":\"alt+f2\",\"category\":\"Sistema\"}]".utf8))
    XCTAssertEqual(r.shortcuts.count,1)
    XCTAssertEqual(r.shortcuts[0].strokes,[KeyStroke(key:"F2",modifiers:.option)])
    do { _=try BindingImport.custom(Data("[{\"profile\":\"finder\",\"title\":\"Bad\",\"keys\":\"wrong-key\"}]".utf8));XCTAssertTrue(false,"Invalid binding accepted") } catch {XCTAssertTrue(true)}
}
