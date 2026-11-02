import Foundation

public enum ShortcutContextKind {case general,conditional,availableNow,unavailable,unverified}
public struct ShortcutContext {
    public let kind:ShortcutContextKind
    public let summary:String
    public let explanation:String
}

/// Presentation never changes a binding, its identity or its original provenance.
public enum ShortcutPresentation {
    private enum Daily:Int {case newTab,close,reopen,find,copy,paste,cut,save,undo,redo}
    private static let dailyRules:[(Daily,NSRegularExpression)]=compileDaily([
        (.reopen,#"\b(reopen|riapri\w*|ripristina\w*)\b.*\b(tab|tabs|scheda|schede|pannello|chius\w*)\b"#),
        (.newTab,#"^(?:(?:open|create|add) (?:a )?)?new (?:chat )?tab\b|^nuov[oa] (scheda|pannello)\b|^open browser tab\b"#),
        (.close,#"^(close|chiud\w*)\b.*\b(tab|tabs|window|finestra|scheda|pannello)\b"#),
        (.find,#"^(find( in (chat|page|document))?|search( in (page|document))?|access search|cerca( nel documento| nella pagina| nella chat)?|trova)$"#),
        (.copy,#"^(copy( (a |the )?selection| selected (text|items))?|copia( testo| la selezione)?)$"#),
        (.paste,#"^(paste( (a |the )?selection| text into the active cell)?|incolla( testo)?)$"#),
        (.cut,#"^(cut( (a |the )?selection)?|taglia( testo)?)$"#),
        (.save,#"^(save( file| document| workbook)?|salva( documento| file)?)$"#),
        (.undo,#"^(undo(.*)?|annulla)$"#),(.redo,#"^(redo(.*)?|ripristina)$"#)
    ])
    private static func compileDaily(_ rules:[(Daily,String)])->[(Daily,NSRegularExpression)] {rules.map{($0.0,try! NSRegularExpression(pattern:$0.1,options:.caseInsensitive))}}
    private static func baseTitle(_ item:Shortcut)->String {item.title.components(separatedBy:" (").first ?? item.title}
    private static let knownActions:[String:Daily]=["editor.action.clipboardCopyAction":.copy,"editor.action.clipboardPasteAction":.paste,"editor.action.clipboardCutAction":.cut,"workbench.action.files.save":.save,"actions.find":.find,"workbench.action.closeActiveEditor":.close,"workbench.action.reopenClosedEditor":.reopen,"undo":.undo,"redo":.redo]
    private static func action(_ item:Shortcut)->Daily? {
        if let action=knownActions[item.actionID ?? item.title] {return action}
        let title=baseTitle(item)
        return dailyRules.first{$0.1.firstMatch(in:title,range:NSRange(title.startIndex...,in:title)) != nil}?.0
    }
    public static func dailyRank(_ item:Shortcut)->Int? {action(item)?.rawValue}
    public static func title(_ item:Shortcut)->String {
        if let global=SystemShortcutIdentity.info(item){return global.title}
        let text=baseTitle(item),lower=text.lowercased()
        switch action(item) {
        case .newTab:
            if lower.contains("chat") {return "Nuova scheda chat"}
            if lower.contains("browser") {return "Nuova scheda del browser"}
            return "Nuova scheda"
        case .close:
            if item.actionID=="workbench.action.closeActiveEditor" || item.title=="workbench.action.closeActiveEditor" {return "Chiudi scheda"}
            let tab=["tab","scheda","pannello"].contains(where:lower.contains)
            let window=["window","finestra"].contains(where:lower.contains)
            if lower.contains("other") || lower.contains("altr") {return tab ? "Chiudi le altre schede":"Chiudi le altre finestre"}
            if lower.contains("all ") || lower.contains("tutt") {return tab ? "Chiudi tutte le schede":"Chiudi tutte le finestre"}
            return tab && window ? "Chiudi scheda o finestra":tab ? "Chiudi scheda":"Chiudi finestra"
        case .reopen:return lower.contains("window") || lower.contains("finestra") ? "Riapri finestra chiusa":"Riapri scheda chiusa"
        case .find:
            if lower.contains("chat") {return "Cerca nella chat"}
            if lower.contains("page") || lower.contains("pagina") {return "Cerca nella pagina"}
            if lower.contains("document") {return "Cerca nel documento"}
            return "Cerca"
        case .copy:return "Copia"
        case .paste:return "Incolla"
        case .cut:return "Taglia"
        case .save:return "Salva"
        case .undo:return "Annulla"
        case .redo:return "Ripristina"
        case nil:return text
        }
    }
    public static let groupOrder=["Schede e finestre","Cercare","Modificare testo","Selezionare","Aprire e salvare","Gestire file","Spostarsi tra cartelle","Navigare","Mostrare e nascondere","Zoom e dimensioni","Scrivere e rispondere","Formattare","Lavorare con tabelle","Presentare e disegnare","Organizzare","Sviluppare e debuggare","Controllare la riproduzione","Scegliere e confermare","Aiuto e riferimenti","Impostazioni dell’app","App e desktop","Catturare lo schermo","Monitor e audio","Sistema","Altri comandi"]
    private static let goals:[(String,NSRegularExpression)]=[
        ("Aiuto e riferimenti",#"\b(help|aiuto|manuale|user guide|thesaurus|dizionario)\b"#),
        ("Zoom e dimensioni",#"\b(zoom|ingrand\w*|rimpicciol\w*|dimensioni? (originali|reali)|dimensione reale|aumentare le dimensioni|diminuire le dimensioni|ritornare alla dimensione)\b|^ridurre$"#),
        ("Mostrare e nascondere",#"\b(hidden|nascost\w*|sidebar|barra laterale|fold|unfold|collapse|uncollapse|ribbon|mostra\w*|nascond\w*)\b"#),
        ("Schede e finestre",#"\b(full screen|fullscreen|tutto schermo|split editor|window|finestr\w*|scheda|schede|pannello|panes?)\b"#),
        ("Selezionare",#"\b(deseleziona\w*|seleziona\w*|select all|selection|select|deselect)\b"#),
        ("Formattare",#"\b(outdent|rientr\w*|apice|pedice|spelling|ortograf\w*|grassetto|corsivo|font|bold|italic|underline|strikethrough)\b"#),
        ("Presentare e disegnare",#"\b(presentazion\w*|diapositiv\w*|slide\w*|oggett\w*|object\w*|forma|forme|shapes?|draw\w*|disegn\w*|animazion\w*|transizion\w*)\b"#),
        ("Lavorare con tabelle",#"\b(define (a )?name|create names|filter|sort|ordina\w*|formula\w*|celle?|righe?|colonn\w*|enter the (date|time))\b"#),
        ("Sviluppare e debuggare",#"\b(bracket|suggest\w*|parameter|definition|references|refactor|breakpoint|debug\w*|visual basic|effort|model picker|permission modes|task|branch|commit\w*|git|context window)\b"#),
        ("Scegliere e confermare",#"\b(confirm\w*|conferm\w*|accept\w*|accetta\w*|dismiss|annulla\w*|cancel|default button|context menu|menu|dialog|dialogo|scelta|picker|focus)\b"#),
        ("Organizzare",#"\b(event\w*|appuntament\w*|reminder\w*|promemoria|contatt\w*|contact\w*|flag|mark|segna\w*|preferit\w*|favorite\w*|bookmark\w*|segnalibr\w*|tag|invite|invit\w*)\b"#),
        ("Navigare",#"\b(jump|andare|andarsene|passare|scorrere|inizio|fine|precedente|successiv\w*|back|forward|reload)\b"#),
        ("Impostazioni dell’app",#"\b(exit|quit|esci|uscire|settings|preferenze|impostazioni)\b"#),
        ("Controllare la riproduzione",#"\b(ridur\w*|riprend\w*|rewind|fast forward|mute|muto|riprodurre|playback|recording|registrazion\w*)\b"#),
        ("Aprire e salvare",#"\b(aprire|apr\w*|open|salvare|salva\w*|save|chiudere|duplicare|esportare|importare)\b"#)
    ].map{($0.0,try! NSRegularExpression(pattern:$0.1,options:.caseInsensitive))}
    public static func group(_ item:Shortcut)->String {
        if let global=SystemShortcutIdentity.info(item){return global.group}
        if item.isSystem {
            return ["App e finestre":"App e desktop","Screenshot":"Catturare lo schermo","Ricerca":"Cercare","Scrittura":"Modificare testo"][item.category] ?? item.category
        }
        if let action=action(item) {
            switch action {
            case .newTab,.close,.reopen:return "Schede e finestre"
            case .find:return "Cercare"
            case .save:return "Aprire e salvare"
            default:return item.profile=="finder" ? "Gestire file":"Modificare testo"
            }
        }
        if item.profile=="finder",item.category=="Navigazione" {return "Spostarsi tra cartelle"}
        if item.profile=="finder",item.category=="File" {return "Gestire file"}
        let title=baseTitle(item),range=NSRange(title.startIndex...,in:title)
        // Precise visibility/zoom rules also refine broad categories such as File.
        if let goal=goals.prefix(3).first(where:{$0.1.firstMatch(in:title,range:range) != nil}) {return goal.0}
        let aliases=["File":"Aprire e salvare","Scrittura e modifica":"Modificare testo","Selezione":"Selezionare","Ricerca":"Cercare","Navigazione":"Navigare","Finestre e schede":"Schede e finestre","Vista":"Mostrare e nascondere","Chat e messaggi":"Scrivere e rispondere","Chat":"Scrivere e rispondere","Formattazione":"Formattare","Tabelle e celle":"Lavorare con tabelle","Terminale e debug":"Sviluppare e debuggare","Riproduzione":"Controllare la riproduzione","Sistema":"Impostazioni dell’app"]
        if let known=aliases[item.category] {return known}
        if item.category != "Altri comandi" {return item.category} // Preserve custom groups.
        return goals.first{$0.1.firstMatch(in:title,range:range) != nil}?.0 ?? "Altri comandi"
    }
    public static func symbol(for group:String)->String {
        ["Schede e finestre":"rectangle.on.rectangle","Cercare":"magnifyingglass","Modificare testo":"pencil","Selezionare":"selection.pin.in.out","Aprire e salvare":"doc","Gestire file":"folder","Spostarsi tra cartelle":"folder","Navigare":"arrow.up.arrow.down","Mostrare e nascondere":"eye","Zoom e dimensioni":"plus.magnifyingglass","Scrivere e rispondere":"bubble.left.and.bubble.right","Formattare":"textformat","Lavorare con tabelle":"tablecells","Presentare e disegnare":"pencil.and.outline","Organizzare":"calendar","Sviluppare e debuggare":"terminal","Controllare la riproduzione":"playpause","Scegliere e confermare":"checkmark.circle","Aiuto e riferimenti":"questionmark.circle","Impostazioni dell’app":"gearshape","App e desktop":"macwindow","Catturare lo schermo":"camera.viewfinder","Monitor e audio":"display","Sistema":"gearshape"][group] ?? ShortcutCategory.symbol(for:group)
    }
    public static func context(_ item:Shortcut)->ShortcutContext {
        let embedded=item.title.components(separatedBy:" (").dropFirst().joined(separator:" (").trimmingCharacters(in:CharacterSet(charactersIn:")"))
        let explicit=[item.context,embedded.isEmpty ? nil:embedded,item.source == .menu ? nil:item.note].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")
        if item.enabled == false {return ShortcutContext(kind:.unavailable,summary:"Non disponibile ora",explanation:explicit)}
        if item.strokes.isEmpty {return ShortcutContext(kind:.unverified,summary:"Tasti da verificare",explanation:item.rawBinding ?? explicit)}
        if item.source == .menu,item.enabled == true {return ShortcutContext(kind:.availableNow,summary:"Disponibile ora",explanation:explicit)}
        if !explicit.isEmpty {
            let lower=explicit.lowercased()
            if lower.contains("nella sezione code") {
                let detail=lower.contains("nuova sessione") ? " · Nuova sessione":lower.contains("sessioni affiancate") ? " · Sessioni affiancate":lower.contains("menu aperto") ? " · Menu aperto":lower.contains("browser integrato attivo") ? " · Browser attivo":lower.contains("durante una risposta") ? " · Risposta in corso":lower.contains("suggerimento") ? " · Prompt suggerito":""
                return ShortcutContext(kind:.conditional,summary:"Sezione Code"+detail,explanation:explicit)
            }
            if let expression=item.context,expression.contains("&&") || expression.contains("||") || expression.contains("!") {
                return ShortcutContext(kind:.conditional,summary:"Condizione dell’app",explanation:explicit)
            }
            let hints:[([String],String)]=[
                (["editorhasselection","text selected","testo selezionato"],"Con testo selezionato"),
                (["built-in browser is available"],"Con browser integrato disponibile"),(["built-in browser is focused"],"Browser integrato attivo"),(["browser"],"Nel browser indicato"),(["terminalfocus","terminal is focused"],"Terminale attivo"),
                (["editortextfocus","editorfocus"],"Nell’editor"),(["chat"],"Nella chat"),
                (["inputfocus","textinputfocus","campo testo"],"In un campo di testo"),
                (["full view","split view"],"Nella vista indicata"),(["when","if ","quando","solo","==","&&","||"],"Nella modalità indicata")
            ]
            let summary=hints.first{keys,_ in keys.contains(where:lower.contains)}?.1 ?? explicit
            return ShortcutContext(kind:.conditional,summary:summary,explanation:explicit)
        }
        switch action(item) {
        case .copy,.cut:return ShortcutContext(kind:.conditional,summary:item.profile=="finder" ? "Con elementi selezionati":"Con contenuto selezionato",explanation:"Richiede una selezione compatibile con il comando nell’app.")
        case .paste:return ShortcutContext(kind:.conditional,summary:"Con contenuto negli appunti",explanation:"Serve una destinazione che accetti il contenuto degli appunti.")
        case .close,.save:return ShortcutContext(kind:.conditional,summary:"Con una finestra o un documento",explanation:"Dipende dalla finestra o dal documento attivo.")
        case .reopen:return ShortcutContext(kind:.conditional,summary:"Dopo aver chiuso una scheda",explanation:"Occorre una scheda chiusa che l’app possa ripristinare.")
        default:break
        }
        return ShortcutContext(kind:.general,summary:item.isSystem ? "Globale":"Uso generale",explanation:"Combinazione documentata senza condizioni specifiche indicate. La disponibilità effettiva dipende dall’app e dal contesto.")
    }
}
