import Foundation
import ShortcutCore

func checkLocalization() throws {
    let initial=L10n.language
    defer {L10n.language=initial}
    XCTAssertEqual(AppLanguage.preferredLanguage(in:["de-DE","it-IT","en-US"]),.it)
    XCTAssertEqual(AppLanguage.preferredLanguage(in:["fr-FR","en-GB","it-IT"]),.en)
    XCTAssertEqual(AppLanguage.preferredLanguage(in:["it-CH","en-US"]),.it)
    XCTAssertEqual(AppLanguage.preferredLanguage(in:["de-DE"]),.en)
    let catalog=try Catalog.loadBundled()
    var required=Set(ShortcutPresentation.groupOrder)
    for item in catalog.shortcuts {
        required.insert(ShortcutPresentation.title(item))
        required.insert(ShortcutPresentation.group(item))
        let context=ShortcutPresentation.context(item)
        for value in [context.summary,context.explanation] {
            if L10n.hasTranslation(value){continue}
            required.formUnion(value.components(separatedBy:" · ").filter{!$0.isEmpty})
        }
    }
    required.formUnion(catalog.profiles.flatMap{[$0.name,$0.note]})
    let missing=required.filter{!L10n.hasTranslation($0)}.sorted()
    if !missing.isEmpty {print("MISSING TRANSLATIONS: "+String(data:try JSONEncoder().encode(missing),encoding:.utf8)!)}
    XCTAssertTrue(missing.isEmpty,"Every bundled display title, group and condition must be translated")
    XCTAssertTrue(L10n.translations.count>3200,"Localization resources must be bundled")
    for (key,row) in L10n.translations {
        XCTAssertFalse(row.it.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,"Italian: \(key)")
        XCTAssertFalse(row.en.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,"English: \(key)")
        // Positional arguments may move, but their types and count must be kept.
        let regex=try NSRegularExpression(pattern:#"%(?:\d+\$)?(?:\.\d+)?[@difs]"#)
        func formats(_ value:String)->[String] {regex.matches(in:value,range:NSRange(value.startIndex...,in:value)).map{String(value[Range($0.range,in:value)!]).replacingOccurrences(of:#"\d+\$"#,with:"",options:.regularExpression)}.sorted()}
        XCTAssertEqual(formats(row.it),formats(row.en))
    }
    let tab=Shortcut(id:"test-tab",profile:"safari",title:"Nuova scheda",category:"Finestre e schede",strokes:[KeyStroke(key:"T",modifiers:.command)],source:.catalog)
    var options=ShortcutOptions();options.hide(tab)
    let identity=ShortcutFilter.displayIdentity(tab),favorite=tab.favoriteID
    for language in [AppLanguage.it,.en] {
        L10n.language=language
        XCTAssertEqual(ShortcutFilter.displayIdentity(tab),identity)
        XCTAssertEqual(tab.favoriteID,favorite)
        XCTAssertTrue(options.isHidden(tab))
        XCTAssertTrue(tab.isFavorite(in:[favorite]))
        options.language=language
        XCTAssertEqual(try JSONDecoder().decode(ShortcutOptions.self,from:JSONEncoder().encode(options)),options)
        XCTAssertEqual(ShortcutFilter.match([tab],modifiers:[],query:language == .it ? "Nuova scheda":"New tab").count,1)
    }
    XCTAssertEqual(try JSONDecoder().decode(ShortcutOptions.self,from:Data("{}".utf8)).language,.system)
    L10n.language = .en
    XCTAssertEqual(ShortcutText.title(tab),"New tab")
    XCTAssertEqual(L10n.text("Nuova scheda"),L10n.text("New tab"))
    XCTAssertEqual(L10n.text("Unrecognized third-party command"),"Unrecognized third-party command")
    XCTAssertEqual(ShortcutText.keys(Shortcut(id:"space",profile:"test",title:"test",category:"test",strokes:[KeyStroke(key:"Space",modifiers:.option)],source:.personal)),"⌥space")
    XCTAssertEqual(L10n.format("%d comandi",2),"2 commands")
    XCTAssertEqual(L10n.text("Assegnazione dichiarata dall’estensione example.ext; attivazione e condizione non verificabili da qui."),"Binding declared by extension example.ext; activation and conditions cannot be verified here.")
}
