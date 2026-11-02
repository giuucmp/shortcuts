import Foundation
import ShortcutCore

func checkCompactLayout() throws {
    let items=(0..<403).map {i in Shortcut(id:"item-\(i)",profile:"finder",title:"Comando \(i)",category:i<330 ? "File":"Categoria personale",strokes:[KeyStroke(key:"K",modifiers:.command)],source:.catalog)}
    for height in [180.0,350,600] {
        for width in [440.0,800,1360] {
            let fit=ShortcutBoardLayout.fit(items,width:width,maximumHeight:height)
            let shown=fit.columns.flatMap(\.groups).flatMap(\.shortcuts)
            XCTAssertEqual(Set(shown.map(\.id)),Set(items.map(\.id)))
            XCTAssertEqual(shown.count,items.count)
            XCTAssertTrue(fit.height<=height+0.001)
            XCTAssertTrue(Double(fit.columns.count)*fit.columnWidth+Double(max(0,fit.columns.count-1))*fit.gap<=width+0.001)
            XCTAssertTrue(fit.columns.allSatisfy {column in
                let occupied=column.groups.reduce(0){$0+$1.height*fit.scale}+Double(max(0,column.groups.count-1))*fit.gap*fit.scale
                return abs(occupied-column.height)<0.001 && column.height<=height+0.001
            })
        }
    }
    XCTAssertTrue(ShortcutBoardLayout.fit([],width:800,maximumHeight:600).columns.isEmpty)
    let catalog=try Catalog.loadBundled()
    for profile in ["finder","excel","vscode","codex","system"] {
        let records=catalog.records(for:profile)
        for size in [(440.0,300.0),(1360,800)] {
            let board=ShortcutBoardLayout.preferred(records,maximumWidth:size.0,maximumHeight:size.1)
            let shown=[board.application,board.system].compactMap{$0}.flatMap(\.columns).flatMap(\.groups).flatMap(\.shortcuts)
            XCTAssertEqual(Set(shown.map(\.id)),Set(records.map(\.id)))
            XCTAssertEqual(shown.count,records.count)
            XCTAssertTrue(board.height<=size.1+0.001)
            XCTAssertTrue(board.width<=size.0+0.001)
            XCTAssertTrue(board.application?.columns.flatMap(\.groups).flatMap(\.shortcuts).allSatisfy{!$0.isSystem} ?? true)
            XCTAssertTrue(board.system?.columns.flatMap(\.groups).flatMap(\.shortcuts).allSatisfy(\.isSystem) ?? true)
        }
    }
    let tiny=ShortcutBoardLayout.fit(items,width:100,maximumHeight:1)
    XCTAssertEqual(tiny.columns.flatMap(\.groups).flatMap(\.shortcuts).count,items.count)
    XCTAssertTrue(tiny.height<=1.001)
    var save=items[0];save.id="save";save.strokes=[KeyStroke(key:"S",modifiers:.command)]
    var other=items[1];other.id="other"
    XCTAssertEqual(ShortcutImportance.ordered([other,save]).map(\.id),["save","other"])
    XCTAssertEqual(ShortcutImportance.ordered([other,save],favorites:["other"]).map(\.id),["other","save"])
    save.enabled=false
    XCTAssertEqual(ShortcutImportance.ordered([save,other]).map(\.id),["other","save"])
}
