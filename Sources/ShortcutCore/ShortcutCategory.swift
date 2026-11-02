import Foundation

public enum ShortcutCategory {
    private struct Rule:Decodable {let name:String;let symbol:String;let pattern:String}
    private static let rules:[Rule] = {
        guard let url=Bundle.module.url(forResource:"category-rules",withExtension:"json"),let data=try? Data(contentsOf:url) else{return []}
        return (try? JSONDecoder().decode([Rule].self,from:data)) ?? []
    }()
    private static let compiled:[(Rule,NSRegularExpression)] = rules.compactMap {rule in
        guard let expression=try? NSRegularExpression(pattern:rule.pattern,options:.caseInsensitive) else{return nil}
        return (rule,expression)
    }
    public static let order=["File","Scrittura e modifica","Selezione","Ricerca","Navigazione","Finestre e schede","Vista","Chat e messaggi","Chat","Formattazione","Tabelle e celle","Terminale e debug","Riproduzione","App e finestre","Screenshot","Monitor e audio","Scrittura","Sistema","Altri comandi"]
    public static func classify(_ title:String)->String {
        // Context headings such as “Keyboard shortcuts” never classify the action.
        let action=title.components(separatedBy:" (").first ?? title
        let words=action.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression)
        let range=NSRange(words.startIndex...,in:words)
        return compiled.first {$0.1.firstMatch(in:words,range:range) != nil}?.0.name ?? "Altri comandi"
    }
    public static func symbol(for category:String)->String {
        rules.first {$0.name==category}?.symbol ?? ["App e finestre":"macwindow","Screenshot":"camera.viewfinder","Monitor e audio":"display","Scrittura":"textformat","Chat":"bubble.left.and.bubble.right"][category] ?? "square.grid.2x2"
    }
}
