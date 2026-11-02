import Foundation

/// Only structural accessibility facts. No document, prompt, clipboard or terminal contents.
public enum FocusArea:String,Sendable {case unknown,other,text,editor,terminal,browser}
public struct ActiveContext:Equatable,Sendable {
    public var area:FocusArea
    public var hasWindow:Bool?
    public var hasTextSelection:Bool?
    public var claudeSection:String?
    public init(area:FocusArea = .unknown,hasWindow:Bool?=nil,hasTextSelection:Bool?=nil,claudeSection:String?=nil) {
        self.area=area;self.hasWindow=hasWindow;self.hasTextSelection=hasTextSelection;self.claudeSection=claudeSection
    }
    public var isTextInput:Bool {area == .text || area == .editor}
    public var label:String {
        switch area {
        case .terminal:return "Terminale attivo"
        case .editor:return "Editor attivo"
        case .text:return "Campo di testo"
        case .browser:return "Pagina del browser"
        case .other:return hasWindow == false ? "Nessuna finestra":"Contesto dell’app"
        case .unknown:return "Contesto parziale"
        }
    }
}

/// Metadata for the focused element and its ancestors, nearest first.
public struct FocusMetadata:Sendable {
    public var role:String
    public var identifier:String
    public var description:String
    public init(role:String,identifier:String="",description:String="") {
        self.role=role;self.identifier=identifier;self.description=description
    }
}
public enum FocusClassifier {
    private static let browsers:Set<String>=["com.apple.Safari","com.microsoft.edgemac","org.mozilla.firefox","org.torproject.torbrowser","com.brave.Browser","com.operasoftware.Opera","company.thebrowser.Browser","com.google.Chrome"]
    private static let terminals:Set<String>=["com.apple.Terminal","com.googlecode.iterm2","com.mitchellh.ghostty","dev.warp.Warp-Stable","net.kovidgoyal.kitty","org.alacritty"]
    public static func area(bundle:String,path:[FocusMetadata])->FocusArea {
        guard let focus=path.first else{return .unknown}
        let isText=["AXTextField","AXTextArea","AXComboBox"].contains(focus.role)
        // A terminal/editor search field is an input, not the terminal/editor itself.
        let firstID=focus.identifier.lowercased()
        if isText && ["search","findinput","find-input","address","urlbar"].contains(where:firstID.contains) {return .text}
        for node in path {
            let id=node.identifier.lowercased(),description=node.description.lowercased()
            if isText && (id.contains("xterm") || id == "terminal" || id.hasPrefix("terminal-input") || description == "terminal input" || description.hasPrefix("terminal input,") || description == "input del terminale") {return .terminal}
            if isText && (id.contains("monaco-editor") || id.contains("code-editor") || description == "editor content" || description.hasPrefix("editor content;") || description.hasPrefix("editor content,") || description.hasPrefix("contenuto dell’editor")) {return .editor}
            if id == "browser-content" || id == "embedded-browser" || id == "browser-webview" {return .browser}
        }
        if isText && terminals.contains(bundle) && focus.role == "AXTextArea" {return .terminal}
        if focus.role == "AXTextArea",["com.microsoft.VSCode","com.todesktop.230313mzl4w4u92"].contains(bundle) {return .unknown}
        if isText {return .text}
        if browsers.contains(bundle) && path.contains(where:{$0.role == "AXWebArea"}) {return .browser}
        // Electron's entire interface is a web area. It is not its built-in browser.
        return focus.role == "AXApplication" ? .unknown:.other
    }
}

public enum ContextTruth:Equatable {case yes,no,unknown
    var negated:Self {self == .yes ? .no:self == .no ? .yes:.unknown}
    static func and(_ a:Self,_ b:Self)->Self {a == .no || b == .no ? .no:a == .yes && b == .yes ? .yes:.unknown}
    static func or(_ a:Self,_ b:Self)->Self {a == .yes || b == .yes ? .yes:a == .no && b == .no ? .no:.unknown}
}

/// Evaluate only the documented boolean subset of VS Code `when` clauses.
/// Unsupported comparisons/regex/context keys stay unknown, never guessed true.
public enum WhenCondition {
    private static let tokenPattern=try! NSRegularExpression(pattern:#"\s*(!==|!=|===|==|=~|\&\&|\|\||!|\(|\)|[^\s!()&|]+)"#)
    public static func evaluate(_ expression:String,context:ActiveContext)->ContextTruth {
        guard expression.utf8.count<=8192 else{return .unknown}
        var parser=Parser(expression,context:context)
        guard parser.tokens.count<=256 else{return .unknown}
        let result=parser.disjunction()
        return parser.index == parser.tokens.count && !parser.invalid ? result:.unknown
    }
    private struct Parser {
        var tokens:[String];var index=0;var invalid=false;var context:ActiveContext
        init(_ text:String,context:ActiveContext) {
            self.context=context
            let text=text.trimmingCharacters(in:.whitespacesAndNewlines)
            let matches=WhenCondition.tokenPattern.matches(in:text,range:NSRange(text.startIndex...,in:text))
            tokens=matches.compactMap{Range($0.range(at:1),in:text).map{String(text[$0])}}
            // Do not accidentally accept malformed single '&'/'|' operators.
            invalid=matches.map{$0.range.length}.reduce(0,+) != (text as NSString).length
        }
        mutating func take(_ value:String)->Bool {if index<tokens.count,tokens[index]==value {index+=1;return true};return false}
        mutating func disjunction()->ContextTruth {var value=conjunction();while take("||"){value = .or(value,conjunction())};return value}
        mutating func conjunction()->ContextTruth {var value=unary();while take("&&"){value = .and(value,unary())};return value}
        mutating func unary()->ContextTruth {
            if take("!"){return unary().negated}
            if take("("){let value=disjunction();if !take(")"){invalid=true};return value}
            guard index<tokens.count else{invalid=true;return .unknown}
            let key=tokens[index];index+=1
            // Comparisons remain a single unknown atom, preserving boolean
            // conjunction/disjunction with focus facts we can actually know.
            if index<tokens.count,["==","===","!=","!==","=~","in","not"].contains(tokens[index]) {
                while index<tokens.count,!["&&","||", "(",")"].contains(tokens[index]) {index+=1}
                return .unknown
            }
            func truth(_ value:Bool?)->ContextTruth {value.map{$0 ? .yes:.no} ?? .unknown}
            switch key {
            case "true":return .yes
            case "false":return .no
            case "terminalFocus":return context.area == .unknown ? .unknown:truth(context.area == .terminal)
            case "editorTextFocus","editorFocus":return context.area == .unknown ? .unknown:truth(context.area == .editor)
            case "inputFocus","textInputFocus":return context.area == .unknown ? .unknown:truth(context.isTextInput)
            case "editorHasSelection":return context.area == .editor ? truth(context.hasTextSelection):context.area == .unknown ? .unknown:.no
            case "isMac":return .yes
            case "isWindows","isLinux":return .no
            default:return .unknown
            }
        }
    }
}

public enum ContextualShortcuts {
    private static let editorActions:Set<String>=["editor.action.commentLine","editor.action.blockComment","editor.action.moveLinesUpAction","editor.action.moveLinesDownAction","editor.action.copyLinesUpAction","editor.action.copyLinesDownAction","editor.action.addSelectionToNextFindMatch","editor.action.revealDefinition","editor.action.triggerSuggest","editor.action.rename","editor.action.formatDocument","editor.action.formatSelection"]
    public static func visible(_ items:[Shortcut],in context:ActiveContext)->[Shortcut] {
        items.filter{applicability($0,in:context) != .no}
    }
    public static func textInputSupplements(_ standard:[Shortcut],profile:String,existing:[Shortcut],context:ActiveContext)->[Shortcut] {
        guard context.isTextInput,!["text","textedit"].contains(profile) else{return []}
        let documentCommands:Set<String>=["Salva documento","Stampa documento","Cerca nel documento","Risultato successivo","Risultato precedente"]
        let occupied=Set(existing.filter{!$0.isSystem && ($0.enabled == false || applicability($0,in:context) != .no)}.map(\.strokes))
        return standard.filter{$0.profile == "text" && !documentCommands.contains($0.title) && !occupied.contains($0.strokes)}.map {item in
            var result=item;result.id="text:\(profile):\(item.id)";result.profile=profile
            result.context="Campo testo compatibile";result.note="Combinazione standard di scrittura: l’app può modificarla."
            return result
        }
    }
    public static func applicability(_ item:Shortcut,in context:ActiveContext)->ContextTruth {
        if item.isSystem {return .yes}
        if item.enabled == false {return .no}
        let embedded=item.title.components(separatedBy:" (").dropFirst().joined(separator:" (")
        let condition=[item.context,embedded].compactMap{$0}.joined(separator:" · ").lowercased()
        let title=ShortcutPresentation.title(item).lowercased()
        if condition.contains("sezione code"),let section=context.claudeSection,section != "Code" {return .no}
        // Commands which *open* a pane deliberately have no focus requirement.
        if condition.contains("terminal is focused") || ["clear terminal","pulisci terminale","cancella terminale"].contains(title) {
            return context.area == .terminal ? .yes:.no
        }
        if condition.contains("built-in browser is focused") || condition.contains("browser integrato attivo") {
            return context.area == .browser ? .yes:.no
        }
        var result:ContextTruth = .yes
        if condition.contains("sezione code") {result=context.claudeSection.map{$0 == "Code" ? .yes:.no} ?? .unknown}
        if condition.contains("campo testo") || condition.contains("in un campo di testo") {
            result = .and(result,context.area == .unknown ? .unknown:context.isTextInput ? .yes:.no)
        }
        if condition.contains("testo selezionato") || condition.contains("text selected") {
            result = .and(result,context.hasTextSelection.map{$0 ? .yes:.no} ?? .unknown)
        }
        if context.hasWindow == false, [.close,.save].contains(windowAction(item)) {return .no}
        if let expression=item.context,looksLikeWhen(expression) {
            result = .and(result,WhenCondition.evaluate(expression,context:context))
        }
        // These commands act on an editor's text; opening/focusing an editor is not included.
        if item.source == .catalog,item.context == nil,["vscode","cursor"].contains(item.profile),editorActions.contains(item.actionID ?? "") {
            result = .and(result,context.area == .unknown ? .unknown:context.area == .editor ? .yes:.no)
        }
        return result
    }
    private static func looksLikeWhen(_ value:String)->Bool {
        value.contains("&&") || value.contains("||") || value.hasPrefix("!") || ["terminalFocus","editorTextFocus","editorFocus","inputFocus","textInputFocus","editorHasSelection"].contains(value)
    }
    private enum WindowAction {case close,save,other}
    private static func windowAction(_ item:Shortcut)->WindowAction {
        let title=ShortcutPresentation.title(item)
        if title == "Salva" {return .save}
        if ["Chiudi finestra","Chiudi scheda","Chiudi scheda o finestra"].contains(title) {return .close}
        return .other
    }
}
