import Foundation
public struct BindingRemoval: Sendable {
    public var profile:String
    public var strokes:[KeyStroke]
    public var actionID:String?
    public var context:String?
}
public struct BindingReport: Sendable {
    public var shortcuts:[Shortcut]=[]
    public var removals:[BindingRemoval]=[]
    public var rejected=0
    public init() {}
}
public enum KeyBindingDialect {case mac, vscode, terminal}
public enum KeyBindingParser {
    public static func parse(_ string:String,dialect:KeyBindingDialect = .mac)->[KeyStroke] {
        let words=string.trimmingCharacters(in:.whitespacesAndNewlines).split(separator:" ")
        var strokes=[KeyStroke]()
        for word in words {
            var s=String(word).lowercased();var m:Modifiers=[]
            let names:[(String,Modifiers)]=[("cmd",.command),("command",.command),("meta",.command),("alt",.option),("option",.option),("ctrl",.control),("control",.control),("shift",.shift),("fn",.function)]
            var consumed=true
            while consumed {consumed=false;for (name,flag) in names {if s.hasPrefix(name+"+"){m.insert(flag);s=String(s.dropFirst(name.count+1));consumed=true;break}}}
            let special=["enter":"Return","return":"Return","tab":"Tab","escape":"Escape","esc":"Escape","space":"Space","up":"Up","down":"Down","left":"Left","right":"Right","backspace":"Delete","delete":"Delete","forwarddelete":"ForwardDelete","home":"Home","end":"End","pageup":"PageUp","pagedown":"PageDown","backtick":"`"]
            let key:String
            if s=="delete",dialect != .mac {key="ForwardDelete"}
            else if let known=special[s] {key=known}
            else if s.count==1 {key=s.uppercased()}
            else if s.range(of:"^f([1-9]|1[0-9]|2[0-4])$",options:.regularExpression) != nil {key=s.uppercased()}
            else{return []}
            strokes.append(KeyStroke(key:key,modifiers:m))
        }
        return strokes
    }
}
public enum BindingImport {
    /// Remove JSONC comments and trailing commas without touching quoted strings/URLs.
    public static func jsonData(_ data:Data) throws -> Data {
        guard let text=String(data:data,encoding:.utf8) else{throw CocoaError(.fileReadInapplicableStringEncoding)}
        let chars=Array(text);var result="";var i=0;var string=false;var escaped=false
        while i<chars.count {
            let c=chars[i]
            if string {result.append(c);if escaped{escaped=false}else if c=="\\"{escaped=true}else if c=="\""{string=false};i+=1;continue}
            if c=="\"" {string=true;result.append(c);i+=1;continue}
            if c=="/",i+1<chars.count,chars[i+1]=="/" {i+=2;while i<chars.count && chars[i] != "\n" {i+=1};continue}
            if c=="/",i+1<chars.count,chars[i+1]=="*" {i+=2;while i+1<chars.count && !(chars[i]=="*" && chars[i+1]=="/"){i+=1};i=min(chars.count,i+2);result.append(" ");continue}
            if c=="," {var j=i+1;while j<chars.count && chars[j].isWhitespace{j+=1};if j<chars.count && (chars[j]=="]" || chars[j]=="}"){i+=1;continue}}
            result.append(c);i+=1
        }
        return Data(result.utf8)
    }
    public static func vscode(_ data:Data,profile:String,source:ShortcutSource = .personal) throws -> BindingReport {
        do {
            guard let rows=try JSONSerialization.jsonObject(with:jsonData(data)) as? [[String:Any]] else{return BindingReport()}
            var report=BindingReport()
            for (i,row) in rows.enumerated() {
                guard let binding=(row["mac"] ?? row["key"]) as? String, let command=row["command"] as? String else{continue}
                let strokes=KeyBindingParser.parse(binding,dialect:.vscode)
                guard !strokes.isEmpty else{report.rejected+=1;continue}
                let context=row["when"] as? String
                if command.hasPrefix("-") || command.isEmpty {report.removals.append(BindingRemoval(profile:profile,strokes:strokes,actionID:command.isEmpty ? nil:String(command.dropFirst()),context:context));continue}
                let label=row["title"] as? String ?? command
                report.shortcuts.append(Shortcut(id:"binding:\(profile):\(i):\(command):\(binding):\(context ?? "")",profile:profile,title:label,category:ShortcutFilter.category(for:label),strokes:strokes,context:context,source:source,note:context == nil ? nil:"Condizione dell’editor: non valutata automaticamente.",actionID:command))
            }
            return report
        } catch { throw error }
    }
    public static func claude(_ data:Data) throws -> BindingReport {
        guard let root=try JSONSerialization.jsonObject(with:jsonData(data)) as? [String:Any],let blocks=root["bindings"] as? [[String:Any]] else{throw CocoaError(.fileReadCorruptFile)}
        var report=BindingReport()
        for block in blocks {
            guard let context=block["context"] as? String,let bindings=block["bindings"] as? [String:Any] else{continue}
            for key in bindings.keys.sorted() {
                let strokes=KeyBindingParser.parse(key,dialect:.terminal);guard !strokes.isEmpty else{report.rejected+=1;continue}
                if bindings[key] is NSNull {report.removals.append(BindingRemoval(profile:"claude-code",strokes:strokes,context:context));continue}
                guard let action=bindings[key] as? String else{report.rejected+=1;continue}
                report.shortcuts.append(Shortcut(id:"claude-binding:\(context):\(key)",profile:"claude-code",title:action,category:ShortcutFilter.category(for:action),strokes:strokes,context:context,source:.personal,note:"Contesto Claude Code; seleziona il profilo nel terminale.",actionID:action))
            }
        }
        return report
    }
    public static func apply(_ base:[Shortcut],report:BindingReport)->[Shortcut] {
        let remaining=base.compactMap { original -> Shortcut? in
            var s=original
            for r in report.removals where r.profile==s.profile && r.strokes==s.strokes && (r.actionID==nil || r.actionID==s.actionID) {
                if r.context==nil || r.context==s.context {return nil}
                if s.context==nil {s.note="Conflitto con una personalizzazione: disattivata quando \(r.context!). La condizione del catalogo non è nota."}
            }
            for a in report.shortcuts where a.source == .personal && a.profile==s.profile && a.strokes==s.strokes {
                if a.context==s.context || a.context==nil {return nil}
                if s.context==nil {s.note="Conflitto con una personalizzazione condizionale: \(a.context!). Verifica nell’editor."}
            }
            return s
        }
        return ShortcutFilter.unique(report.shortcuts + remaining)
    }
}
extension BindingReport {
    init(shortcuts:[Shortcut],removals:[BindingRemoval],rejected:Int){self.shortcuts=shortcuts;self.removals=removals;self.rejected=rejected}
}
extension BindingImport {
    public static func custom(_ data:Data) throws -> BindingReport {
        guard let rows=try JSONSerialization.jsonObject(with:jsonData(data)) as? [[String:Any]],rows.count<=10000 else {throw CocoaError(.fileReadCorruptFile)}
        var report=BindingReport()
        for row in rows {
            guard let profile=row["profile"] as? String,!profile.isEmpty,let title=row["title"] as? String,!title.isEmpty,let keys=row["keys"] as? String else{throw CocoaError(.fileReadCorruptFile)}
            let strokes=KeyBindingParser.parse(keys)
            guard !strokes.isEmpty,strokes.count<=5 else{throw CocoaError(.fileReadCorruptFile)}
            let id="custom:\(profile):\(title):\(keys):\(row["context"] as? String ?? "")"
            report.shortcuts.append(Shortcut(id:id,profile:profile,title:title,category:row["category"] as? String ?? ShortcutFilter.category(for:title),strokes:strokes,context:row["context"] as? String,source:.personal,note:row["note"] as? String))
        }
        return report
    }
}
