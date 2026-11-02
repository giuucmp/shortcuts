import Foundation
import ShortcutCore

func checkAuditRegressions() throws {
    let saved=try JSONDecoder().decode(ShortcutOptions.self,from:Data(#"{"hiddenKeys":["finder|nuova scheda"],"showSystem":false,"theme":"Scuro","textSize":"future-value"}"#.utf8))
    XCTAssertEqual(saved.hiddenKeys,["finder|nuova scheda"])
    XCTAssertFalse(saved.showSystem)
    XCTAssertEqual(saved.theme,.dark)
    XCTAssertEqual(saved.textSize,.standard)
    XCTAssertTrue(saved.showContext)
    XCTAssertEqual(try JSONDecoder().decode(ShortcutOptions.self,from:Data("{}".utf8)),ShortcutOptions())

    let copy=Shortcut(id:"copy-a",profile:"excel",title:"Copy selection",category:"File",strokes:[KeyStroke(key:"C",modifiers:.command)],source:.catalog)
    var variant=copy;variant.id="copy-b";variant.title="Copy a selection"
    let rows=ShortcutFilter.forDisplay([copy,variant],favorites:[variant.id])
    XCTAssertEqual(rows.count,1)
    XCTAssertEqual(rows[0].knownIDs,[copy.id,variant.id])
    XCTAssertTrue(rows[0].isFavorite(in:[copy.id]))
    var otherContext=variant;otherContext.id="different-context";otherContext.context="Solo in una tabella"
    var otherBinding=variant;otherBinding.id="different-binding";otherBinding.strokes=[KeyStroke(key:"C",modifiers:.control)]
    XCTAssertEqual(ShortcutFilter.forDisplay([copy,variant,otherContext,otherBinding]).count,3)
    var otherNote=variant;otherNote.id="different-note";otherNote.note="Solo in una modalità diversa"
    XCTAssertEqual(ShortcutFilter.forDisplay(ShortcutFilter.merge(catalog:[variant,otherNote],actual:[])).count,2)
    var menu=copy;menu.id="menu-copy";menu.source = .menu;menu.enabled=false
    let merged=ShortcutFilter.merge(catalog:[copy],actual:[menu])
    XCTAssertEqual(merged.count,1)
    XCTAssertTrue(merged[0].isFavorite(in:[copy.id]))
    XCTAssertEqual(merged[0].enabled,false)
    let starred=FavoriteSelection.toggling(merged[0],in:[])
    XCTAssertTrue(copy.isFavorite(in:starred))
    let unstarred=FavoriteSelection.toggling(copy,in:starred)
    XCTAssertFalse(merged[0].isFavorite(in:unstarred),"A star removed in an inactive app's catalog must not return in its live menu")
    let migrated=FavoriteSelection.migrated([menu.id,"unknown-legacy"],using:merged)
    XCTAssertTrue(copy.isFavorite(in:migrated))
    XCTAssertTrue(migrated.contains("unknown-legacy"),"Unresolved old favorites are retained")
    XCTAssertFalse(merged[0].isFavorite(in:FavoriteSelection.toggling(copy,in:migrated)))
    var annotated=copy;annotated.note="Solo con una selezione compatibile"
    let annotatedMenu=ShortcutFilter.merge(catalog:[annotated],actual:[menu])[0]
    XCTAssertEqual(annotatedMenu.favoriteID,annotated.favoriteID)
    var history=PracticeProgress();history.record(remembered:true)
    XCTAssertEqual(PracticeProgress.latest(for:merged[0],in:[copy.id:history])?.confidence,1)
    var remapped=menu;remapped.strokes=[KeyStroke(key:"K",modifiers:.command)]
    XCTAssertFalse(ShortcutFilter.merge(catalog:[copy],actual:[remapped])[0].knownIDs.contains(copy.id),"Different keys must not inherit learned answers")

    var snapshot=PanelSnapshot(items:[copy],modifiers:.command,favorites:[copy.id])
    XCTAssertFalse(snapshot.acceptFirstApplicationResult([variant,otherContext],modifiers:.command,favorites:[otherContext.id]))
    XCTAssertEqual(snapshot.items.map(\.id),[copy.id])
    XCTAssertEqual(snapshot.favorites,[copy.id])
    XCTAssertTrue(ShortcutFilter.match(snapshot.items,modifiers:[.command,.shift]).isEmpty)
    var system=copy;system.id="global";system.profile="system"
    var bootstrap=PanelSnapshot(items:[system],modifiers:.command)
    XCTAssertFalse(bootstrap.acceptFirstApplicationResult([system],modifiers:.command))
    XCTAssertTrue(bootstrap.acceptFirstApplicationResult([system,copy],modifiers:.command))
    XCTAssertFalse(bootstrap.acceptFirstApplicationResult([system,variant],modifiers:.command))
    XCTAssertEqual(bootstrap.items.map(\.id),[system.id,copy.id])
    var readiness=FocusReadiness()
    let old=readiness.begin(at:0)
    let current=readiness.begin(at:0.04)
    XCTAssertFalse(readiness.finish(old))
    XCTAssertTrue(readiness.isWaiting(at:0.1))
    XCTAssertFalse(readiness.isWaiting(at:0.17),"An unresponsive AX app must not defer the panel indefinitely")
    XCTAssertTrue(readiness.finish(current))
    XCTAssertFalse(readiness.isWaiting(at:0.18))
    let cancelled=readiness.begin(at:1);readiness.cancel()
    XCTAssertFalse(readiness.finish(cancelled))

    let catalog=try Catalog.loadBundled()
    let excel=ShortcutFilter.merge(catalog:catalog.records(for:"excel"),actual:[])
    let deduplicated=ShortcutFilter.forDisplay(excel)
    for key in ["C","V","X"] {
        let rows=deduplicated.filter{$0.strokes==[KeyStroke(key:key,modifiers:.command)] && ["Copia","Incolla","Taglia"].contains(ShortcutPresentation.title($0))}
        XCTAssertEqual(rows.count,1)
    }
    XCTAssertEqual(deduplicated.reduce(into:Set<String>()){$0.formUnion($1.knownIDs)},excel.reduce(into:Set<String>()){$0.formUnion($1.knownIDs)})
    for profile in ["finder","excel","vscode"] {
        let items=ShortcutFilter.match(ShortcutFilter.forDisplay(catalog.records(for:profile)),modifiers:.command)
        for height in [300.0,780] {
            let baselineSystem=ShortcutBoardLayout.fit(items.filter(\.isSystem),width:536,maximumHeight:min(110,height*0.22),secondary:true)
            let baselineApp=ShortcutBoardLayout.fit(items.filter{!$0.isSystem},width:536,maximumHeight:height-baselineSystem.height-26)
            let board=ShortcutBoardLayout.board(items,width:560,maximumContentHeight:height)
            XCTAssertTrue((board.application?.scale ?? 1)>=baselineApp.scale-0.001,"System legibility must not shrink application text")
            XCTAssertTrue(board.contentHeight<=height+0.001)
        }
    }
    let finder=ShortcutFilter.match(ShortcutFilter.forDisplay(catalog.records(for:"finder")),modifiers:.command)
    let board=ShortcutBoardLayout.preferred(finder,maximumWidth:1400,maximumHeight:850)
    XCTAssertTrue((board.system?.scale ?? 0)>=0.8,"Finder has enough space for readable macOS shortcuts")
}
