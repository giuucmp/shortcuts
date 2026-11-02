import Foundation

/// Some app reference tables repeat OS commands. Match both a documented
/// action and its binding; a matching key alone never reclassifies an app action.
enum SystemShortcutIdentity {
    static func info(_ item:Shortcut)->(title:String,group:String)? {
        guard item.source == .catalog,item.strokes.count==1,let stroke=item.strokes.first else{return nil}
        let text=item.title.lowercased(),key=stroke.key.lowercased(),flags=stroke.modifiers
        if key=="tab",flags == .command || flags == [.command,.shift] {
            if ["application","applicazion","all’app","all'app","next app","previous app"].contains(where:text.contains) {
                return (flags == .command ? "Passa all’app successiva":"Passa all’app precedente","App e desktop")
            }
        }
        if key=="space",flags == .command,text.contains("spotlight") {return ("Apri Spotlight","Cercare")}
        if key=="space",flags == [.command,.option],text.contains("finder"),text.contains("search") || text.contains("ricerc") {return ("Apri ricerca Finder","Cercare")}
        if key=="q",flags == [.command,.control],(text.contains("lock") && text.contains("screen")) || (text.contains("blocca") && text.contains("schermo")) {return ("Blocca lo schermo","Sistema")}
        if ["3","4","5"].contains(key),flags.isSuperset(of:[.command,.shift]),flags.subtracting([.command,.shift,.control]).isEmpty,["screenshot","screen shot","istantanea","scherm"].contains(where:text.contains) {
            if key=="5",!flags.contains(.control) {return ("Screenshot e registrazione","Catturare lo schermo")}
            if key != "5" {return ("Screenshot"+(flags.contains(.control) ? " negli appunti":"")+(key=="3" ? ": schermo intero":": area"),"Catturare lo schermo")}
        }
        return nil
    }
}
