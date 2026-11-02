import Foundation
import ShortcutCore
struct BindingLoad {var report:BindingReport;var message:String}
enum BindingSources {
    static func load(profile:String)->BindingLoad {
        var report=BindingReport();var errors=0;var files=0
        let home=FileManager.default.homeDirectoryForCurrentUser
        func append(_ r:BindingReport) {report.shortcuts+=r.shortcuts;report.removals+=r.removals;report.rejected+=r.rejected}
        if profile=="claude-code" {
            let path=home.appendingPathComponent(".claude/keybindings.json")
            if FileManager.default.fileExists(atPath:path.path) {do{append(try BindingImport.claude(Data(contentsOf:path)));files+=1}catch{errors+=1}}
        }
        if ["vscode","cursor"].contains(profile) {
            let app=profile=="vscode" ? "Visual Studio Code":"Cursor"
            let support=profile=="vscode" ? "Code":"Cursor"
            let folder=profile=="vscode" ? ".vscode/extensions":".cursor/extensions"
            let roots=[URL(fileURLWithPath:"/Applications/\(app).app/Contents/Resources/app/extensions"),home.appendingPathComponent(folder)]
            for root in roots {
                let children=(try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isDirectoryKey],options:.skipsHiddenFiles)) ?? []
                for dir in children.prefix(1000) {
                    let package=dir.appendingPathComponent("package.json")
                    guard let data=try? Data(contentsOf:package),data.count<5_000_000,
                          let json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let contributes=json["contributes"] as? [String:Any] else{continue}
                    let bindings=(contributes["keybindings"] as? [[String:Any]]) ?? (contributes["keybindings"] as? [String:Any]).map{[$0]} ?? []
                    if bindings.isEmpty{continue}
                    let commands=contributes["commands"] as? [[String:Any]] ?? []
                    var titles=[String:String]()
                    for c in commands {if let id=c["command"] as? String,let title=c["title"] as? String {titles[id]=title}}
                    let localized=(try? Data(contentsOf:dir.appendingPathComponent("package.nls.json"))).flatMap{try? JSONSerialization.jsonObject(with:$0) as? [String:String]} ?? [:]
                    let prepared=bindings.map { b -> [String:Any] in
                        var row=b
                        if let command=b["command"] as? String,let title=titles[command] {
                            row["title"]=title.hasPrefix("%") && title.hasSuffix("%") ? localized[String(title.dropFirst().dropLast())] ?? command : title
                        }
                        return row
                    }
                    if let encoded=try? JSONSerialization.data(withJSONObject:prepared),var parsed=try? BindingImport.vscode(encoded,profile:profile,source:.extensionBinding) {
                        let extensionID=dir.lastPathComponent
                        parsed.shortcuts=parsed.shortcuts.map{ s in var t=s;t.id=extensionID+":"+t.id;t.note="Assegnazione dichiarata dall’estensione \(extensionID); attivazione e condizione non verificabili da qui.";return t}
                        append(parsed);files+=1
                    }
                }
            }
            // User overrides last; never read settings, workspace content, arguments or credentials.
            let user=home.appendingPathComponent("Library/Application Support/\(support)/User/keybindings.json")
            if FileManager.default.fileExists(atPath:user.path) {
                do {let overrides=try BindingImport.vscode(Data(contentsOf:user),profile:profile);report.shortcuts=BindingImport.apply(report.shortcuts,report:overrides);report.removals+=overrides.removals;report.rejected+=overrides.rejected;files+=1}catch{errors+=1}
            }
        }
        var message=L10n.format("%d assegnazioni lette da %d file di configurazione. Le condizioni delle estensioni restano da verificare.",report.shortcuts.count,files)
        if files==0 {message=L10n.text("Nessuna personalizzazione leggibile rilevata. I comandi effettivi esposti nei menu vengono aggiunti automaticamente.")}
        if errors>0 || report.rejected>0 {message += " "+L10n.format("%d file non leggibili; %d combinazioni non interpretate.",errors,report.rejected)}
        return BindingLoad(report:report,message:message)
    }
}
