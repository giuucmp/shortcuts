import Foundation

/// A transparent starting order for learning. Favorites take precedence; no usage
/// history is collected, and these tiers are suggestions rather than measured frequency.
public enum ShortcutImportance:Int {
    case essential=0, useful=1, other=2
    public static func level(_ item:Shortcut)->Self {
        guard let stroke=item.strokes.first else{return .other}
        let key=stroke.key.lowercased(), mods=stroke.modifiers
        let text=(item.title+" "+(item.actionID ?? "")).lowercased()
        if item.strokes.count==1 {
            if mods == .command && ["c","v","x","z","a","s","f","n","o","w"].contains(key) {return .essential}
            if mods == [.command,.shift] && ["z","s","t"].contains(key) {return .essential}
            if ["finder"].contains(item.profile) && ((mods.isEmpty && key=="space") || (mods == [.command,.shift] && key=="g") || (mods == [.command,.option] && key=="v")) {return .essential}
            if ["safari","edge","chrome","firefox","brave","arc"].contains(item.profile), mods == .command, ["l","r","t","+","-"].contains(key) {return .essential}
            if ["vscode","cursor"].contains(item.profile), ((mods == .command && key=="p") || (mods == [.command,.shift] && ["p","f"].contains(key))) {return .essential}
            if item.isSystem, mods == .command, ["tab","space"].contains(key) {return .essential}
            if ["claude-code","codex-cli"].contains(item.profile), (mods.isEmpty && ["return","enter","escape"].contains(key) || mods == .control && key=="c") {return .essential}
        }
        if ["clipboardcopy","clipboardpaste","quickopen","command palette","tavolozza dei comandi"].contains(where:text.contains) {return .essential}
        if ["save","salva","undo","annulla","redo","ripristin","find","trova","cerc","search","zoom","bold","grassetto","italic","corsivo","new tab","nuovo pannello","quick look","anteprima rapida","screenshot","istantanea","fullscreen","schermo intero"].contains(where:text.contains) {return .useful}
        if mods == .command && ["p","b","i","u","q","h","m","d",",","+","-","0"].contains(key) {return .useful}
        return .other
    }
    public static func ordered(_ items:[Shortcut],favorites:Set<String>=[])->[Shortcut] {
        items.enumerated().map{(offset:$0.offset,element:$0.element,daily:ShortcutPresentation.dailyRank($0.element),priority:level($0.element).rawValue)}.sorted {a,b in
            let aUnavailable=a.element.enabled == false, bUnavailable=b.element.enabled == false
            if aUnavailable != bUnavailable {return !aUnavailable}
            let af=a.element.isFavorite(in:favorites),bf=b.element.isFavorite(in:favorites)
            if af != bf {return af}
            let ad=a.daily,bd=b.daily
            if ad != bd {return (ad ?? 100)<(bd ?? 100)}
            let ap=a.priority,bp=b.priority
            return ap == bp ? a.offset<b.offset:ap<bp
        }.map(\.element)
    }
}
