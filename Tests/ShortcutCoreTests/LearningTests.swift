import Foundation
import ShortcutCore

func checkGroupReadingOrder() {
    let categories=["File","Scrittura e modifica","Selezione","Ricerca","Navigazione","Finestre e schede","Vista","Formattazione","Altri comandi"]
    let counts=[3,28,7,1,19,2,9,16,15]
    let items=categories.enumerated().flatMap {index,category in
        (0..<counts[index]).map {row in Shortcut(id:"order-\(index)-\(row)",profile:"test",title:"Azione \(index) \(row)",category:category,strokes:[KeyStroke(key:"K",modifiers:row%2==0 ? [.command,.shift]:.command)],source:.catalog)}
    }
    for flags:Modifiers in [.command,[.command,.shift]] {
        let filtered=ShortcutFilter.match(items,modifiers:flags)
        let fit=ShortcutBoardLayout.fit(filtered,width:1100,maximumHeight:700)
        let names=fit.columns.flatMap(\.groups).map(\.category)
        let indexes=names.map{ShortcutPresentation.groupOrder.firstIndex(of:$0) ?? 999}
        XCTAssertEqual(indexes,indexes.sorted())
    }
}

func checkLearningPresentation() throws {
    let catalog=try Catalog.loadBundled()
    let finder=catalog.records(for:"finder")
    XCTAssertEqual(ShortcutPresentation.group(catalog.records(for:"keynote").first{$0.title=="Ridurre"}!),"Zoom e dimensioni")
    let tab=finder.first{$0.profile=="finder" && $0.strokes == [KeyStroke(key:"T",modifiers:.command)]}!
    let hidden=finder.first{$0.profile=="finder" && $0.strokes == [KeyStroke(key:".",modifiers:[.command,.shift])]}!
    XCTAssertEqual(ShortcutPresentation.title(tab),"Nuova scheda")
    XCTAssertTrue(ShortcutPresentation.dailyRank(tab) != nil)
    XCTAssertEqual(ShortcutPresentation.group(tab),"Schede e finestre")
    XCTAssertEqual(ShortcutPresentation.group(hidden),"Mostrare e nascondere")
    XCTAssertTrue(ShortcutFilter.match(finder,modifiers:[],query:"nuova scheda").contains{$0.id==tab.id})
    XCTAssertTrue(ShortcutFilter.match(finder,modifiers:[],query:"cmd + shift + .").contains{$0.id==hidden.id})
    var scoped=tab;scoped.title="Close other tabs"
    XCTAssertEqual(ShortcutPresentation.title(scoped),"Chiudi le altre schede")
    scoped.title="Open file in a new tab"
    XCTAssertEqual(ShortcutPresentation.title(scoped),"Open file in a new tab")
    let editorSymbol=catalog.records(for:"vscode").first{$0.title=="Show All Symbols"}!
    XCTAssertFalse(ShortcutPresentation.title(editorSymbol)=="Nuova scheda")
    XCTAssertEqual(ShortcutPresentation.group(finder.first{$0.title=="Cartella superiore"}!),"Spostarsi tra cartelle")
    var copy=Shortcut(id:"copy",profile:"textedit",title:"Copy",category:"Scrittura e modifica",strokes:[KeyStroke(key:"C",modifiers:.command)],source:.catalog)
    XCTAssertEqual(ShortcutPresentation.context(copy).kind,.conditional)
    XCTAssertTrue(ShortcutPresentation.context(copy).summary.contains("selezionat"))
    copy.enabled=false
    XCTAssertEqual(ShortcutPresentation.context(copy).kind,.unavailable)
    copy.enabled=true;copy.source = .menu
    XCTAssertEqual(ShortcutPresentation.context(copy).kind,.availableNow)
    var personal=copy;personal.id="personal-copy";personal.title="editor.action.clipboardCopyAction";personal.source = .personal;personal.enabled=nil;personal.actionID="editor.action.clipboardCopyAction"
    XCTAssertEqual(ShortcutPresentation.title(personal),"Copia")
    personal.title="workbench.action.closeActiveEditor";personal.actionID=personal.title
    XCTAssertEqual(ShortcutPresentation.title(personal),"Chiudi scheda")
    let conditional=Shortcut(id:"conditional",profile:"codex",title:"Open browser tab (When the built-in browser is available)",category:"Finestre e schede",strokes:[KeyStroke(key:"T",modifiers:.command)],source:.catalog)
    XCTAssertEqual(ShortcutPresentation.title(conditional),"Nuova scheda del browser")
    XCTAssertEqual(ShortcutPresentation.context(conditional).kind,.conditional)
    XCTAssertTrue(ShortcutPresentation.context(conditional).summary.contains("browser"))
    XCTAssertTrue(ShortcutPresentation.context(conditional).explanation.contains("When the built-in browser"))
    for flags:Modifiers in [.command,[.command,.shift]] {
        let filtered=ShortcutFilter.match(finder,modifiers:flags)
        let layout=ShortcutBoardLayout.preferred(filtered,maximumWidth:1300,maximumHeight:800)
        let ids=[layout.application,layout.system].compactMap{$0}.flatMap(\.columns).flatMap(\.groups).flatMap(\.shortcuts).map(\.id)
        XCTAssertTrue(ids.contains(hidden.id))
        if flags == .command {XCTAssertTrue(ids.contains(tab.id))}
    }
}

func checkPracticeSessions() throws {
    let items=(0..<8).map {Shortcut(id:"practice-\($0)",profile:"finder",title:"Azione \($0)",category:"File",strokes:[KeyStroke(key:"\($0)",modifiers:.command)],source:.catalog)}
    var disabled=items[0];disabled.id="disabled";disabled.enabled=false
    var unknown=items[0];unknown.id="unknown";unknown.strokes=[]
    var system=items[0];system.id="system";system.profile="system"
    var session=PracticeSession(items:items+[disabled,unknown,system,items[0]],favorites:["practice-3"],progress:[:])
    XCTAssertEqual(session.cards.count,5)
    XCTAssertEqual(session.current?.id,"practice-3")
    XCTAssertFalse(session.cards.contains{$0.id=="disabled" || $0.id=="unknown" || $0.isSystem})
    XCTAssertEqual(Set(session.cards.map(\.id)).count,session.cards.count)
    XCTAssertTrue(session.rate(remembered:true)==nil,"A hidden answer cannot be marked complete")
    XCTAssertEqual(session.answered,0)
    session.reveal()
    XCTAssertEqual(session.rate(remembered:false)?.id,"practice-3")
    XCTAssertFalse(session.revealed)
    XCTAssertEqual(session.reviewCards.map(\.id),["practice-3"])
    while !session.completed {session.reveal();_ = session.rate(remembered:true)}
    XCTAssertEqual(session.rememberedCount,4)
    XCTAssertEqual(session.answered,5)
    XCTAssertTrue(session.current==nil)
    XCTAssertTrue(session.rate(remembered:true)==nil)
    var contextA=items[0];contextA.id="context-a";contextA.title="Open browser tab (When browser A is focused)"
    var contextB=contextA;contextB.id="context-b";contextB.title="Open browser tab (When browser B is focused)"
    XCTAssertEqual(PracticeSession(items:[contextA,contextB]).cards.count,2)
    let empty=PracticeSession(items:[unknown,disabled,system],favorites:[],progress:[:])
    XCTAssertTrue(empty.cards.isEmpty)
    XCTAssertEqual(PracticeSession(items:[system],includeSystem:true).cards.count,1)
    var history=PracticeProgress();history.record(remembered:true);history.record(remembered:true)
    let persisted=try JSONDecoder().decode(PracticeProgress.self,from:JSONEncoder().encode(history))
    XCTAssertEqual(persisted.confidence,2)
    let next=PracticeSession(items:items,favorites:["practice-3"],progress:["practice-3":persisted])
    XCTAssertFalse(next.cards.contains{$0.id=="practice-3"},"Fresh commands should precede an already recalled favorite")
    history.record(remembered:false)
    XCTAssertEqual(history.confidence,0)
}

func checkCustomization() throws {
    let catalog=try Catalog.loadBundled()
    let finder=catalog.records(for:"finder")
    let tab=finder.first{$0.profile=="finder" && $0.strokes == [KeyStroke(key:"T",modifiers:.command)]}!
    let global=finder.first{$0.profile=="system" && $0.strokes == [KeyStroke(key:"Tab",modifiers:.command)]}!
    var options=ShortcutOptions()
    options.hide(tab)
    XCTAssertFalse(options.visible(finder).contains{$0.id==tab.id})
    var menu=tab;menu.id="menu-finder-tab";menu.title="Nuova scheda";menu.source = .menu
    XCTAssertTrue(options.isHidden(menu),"Hiding an action must also cover its matching menu title")
    var differentApp=tab;differentApp.profile="safari"
    XCTAssertFalse(options.isHidden(differentApp))
    options.hide(global)
    XCTAssertFalse(options.visible(finder).contains{$0.id==global.id})
    options.showSystem=false
    XCTAssertTrue(options.visible(finder).allSatisfy{!$0.isSystem})
    let appDocumentedGlobal=catalog.records(for:"excel").first{$0.profile=="excel" && $0.strokes == [KeyStroke(key:"Tab",modifiers:.command)]}!
    XCTAssertTrue(appDocumentedGlobal.isSystem)
    XCTAssertFalse(options.visible([appDocumentedGlobal]).contains{$0.id==appDocumentedGlobal.id})
    var shared=ShortcutOptions();shared.hide(global)
    XCTAssertTrue(shared.isHidden(appDocumentedGlobal))
    options.show(tab)
    XCTAssertTrue(options.visible(finder).contains{$0.id==tab.id})
    options.textSize = .large;options.theme = .dark;options.background = .solid;options.position = .left
    let saved=try JSONDecoder().decode(ShortcutOptions.self,from:JSONEncoder().encode(options))
    XCTAssertEqual(saved.hiddenKeys,options.hiddenKeys)
    XCTAssertEqual(saved.textSize,.large)
    XCTAssertEqual(saved.theme,.dark)
    XCTAssertFalse(saved.showSystem)
    for size in ShortcutTextSize.allCases {
        for notes in [true,false] {
            let layout=ShortcutBoardLayout.preferred(finder,maximumWidth:1280,maximumHeight:720,textScale:size.scale,showContext:notes)
            let shown=[layout.application,layout.system].compactMap{$0}.flatMap(\.columns).flatMap(\.groups).flatMap(\.shortcuts)
            XCTAssertEqual(shown.count,finder.count)
            XCTAssertTrue(layout.width<=1280 && layout.height<=720.001)
        }
    }
    options.hideConditional=true
    let copy=finder.first{$0.title=="Copia"}!
    XCTAssertFalse(options.visible(finder).contains{$0.id==copy.id})
}
