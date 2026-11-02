import Foundation
import ShortcutCore

func checkGrouping() throws {
    for (title,category) in [("Open command menu","Ricerca"),("Toggle sidebar","Vista"),("New chat","Chat e messaggi"),("Open folder","File"),("Copy conversation path","Scrittura e modifica"),("Open keyboard shortcuts","Sistema"),("Close current tab or window","Finestre e schede"),("Avvia debug","Terminale e debug"),("Grassetto","Formattazione")] {
        XCTAssertEqual(ShortcutCategory.classify(title),category)
    }
    XCTAssertEqual(ShortcutCategory.classify("Shortcut unrelated to editing"),"Altri comandi")
    XCTAssertEqual(ShortcutCategory.classify("Open a new blank workbook"),"File")
    XCTAssertEqual(ShortcutCategory.classify("Add an outline border to the bottom of the selection"),"Formattazione")
    XCTAssertEqual(ShortcutCategory.classify("Calculate all open workbooks"),"Tabelle e celle")
    XCTAssertEqual(ShortcutCategory.classify("Reload browser page (When the built-in browser is focused)"),"Navigazione")
    let catalog=try Catalog.loadBundled()
    let codex=catalog.shortcuts.filter{$0.profile=="codex"}
    XCTAssertEqual(codex.first{$0.title=="Open command menu"}?.category,"Ricerca")
    XCTAssertEqual(codex.first{$0.title=="Toggle sidebar"}?.category,"Vista")
    let small=(0..<8).map {i in Shortcut(id:"small-\(i)",profile:"finder",title:"Comando \(i)",category:i<4 ? "File":"Ricerca",strokes:[KeyStroke(key:"K",modifiers:.command)],source:.catalog)}
    let board=ShortcutBoardLayout.preferred(small,maximumWidth:1400,maximumHeight:850)
    XCTAssertTrue(board.height<400,"Sparse panels must shrink to the content")
    XCTAssertTrue(board.width<900)
    XCTAssertEqual(board.application?.columns.flatMap(\.groups).count,2)
    XCTAssertTrue(board.application?.columns.flatMap(\.groups).allSatisfy{$0.partCount==1} ?? false)
    for count in [1,40,403,2000] {
        let all=(0..<count).map {i in Shortcut(id:"all-\(i)",profile:"finder",title:"Comando \(i)",category:"Gruppo \(i%9)",strokes:[KeyStroke(key:"K",modifiers:.command)],source:.catalog)}
        let fit=ShortcutBoardLayout.fit(all,width:1280,maximumHeight:650)
        let shown=fit.columns.flatMap(\.groups).flatMap(\.shortcuts)
        XCTAssertEqual(shown.count,all.count)
        XCTAssertEqual(Set(shown.map(\.id)),Set(all.map(\.id)))
        XCTAssertTrue(fit.height<=650.001)
        XCTAssertTrue(fit.columns.allSatisfy{$0.groups.allSatisfy{group in group.shortcuts.allSatisfy{ShortcutPresentation.group($0)==group.category}}})
    }
}
