import AppKit
import ApplicationServices
import Carbon
import ShortcutCore

struct ScanResult {
    var shortcuts: [Shortcut]
    var message: String
    var complete: Bool
    var focusedRole: String?
    var frame: CGRect?
    var menuAvailable=false
}
enum AccessibilityReader {
    static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,name as CFString,&result) == .success else { return nil }
        return result
    }
    static func element(_ item: CFTypeRef?) -> AXUIElement? {
        guard let item, CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(item,to:AXUIElement.self)
    }
    static func scan(pid: pid_t, profile: String) -> ScanResult {
        guard pid>0 else {return ScanResult(shortcuts:[],message:L10n.text("Attiva un’app per leggerne i menu."),complete:false)}
        // The actual AX operation is authoritative. macOS still enforces access;
        // a preflight boolean must not discard a menu the API lets us read.
        let deadline=Date().addingTimeInterval(3)
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(),0.12)
        let app=AXUIElementCreateApplication(pid)
        let startWindow=element(value(app,kAXFocusedWindowAttribute))
        let focus=element(value(app,kAXFocusedUIElementAttribute))
        let role=focus.flatMap { value($0,kAXRoleAttribute) as? String }
        var frame: CGRect?
        if let window=element(value(app,kAXFocusedWindowAttribute)), let p=value(window,kAXPositionAttribute), let s=value(window,kAXSizeAttribute), CFGetTypeID(p)==AXValueGetTypeID(), CFGetTypeID(s)==AXValueGetTypeID() {
            var point=CGPoint.zero;var size=CGSize.zero
            AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point)
            AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size)
            frame=CGRect(origin:point,size:size)
        }
        var menuValue:CFTypeRef?
        let menuStatus=AXUIElementCopyAttributeValue(app,kAXMenuBarAttribute as CFString,&menuValue)
        guard let menu=element(menuValue) else {
            let message=menuStatus == .apiDisabled ? L10n.text("Accessibilità non ancora operativa. Dopo averla abilitata, riavvia Shortcuts.") : L10n.format("Menu non disponibile (AX %d). Riprova con l’app in primo piano.",menuStatus.rawValue)
            return ScanResult(shortcuts:[],message:message,complete:false,focusedRole:role,frame:frame)
        }
        var result=[Shortcut](); var nodes=0; var partial=false
        func visit(_ node: AXUIElement, path: [String], depth: Int) {
            guard nodes < 4000, depth < 15, Date() < deadline else { partial=true;return }
            nodes += 1
            let role=value(node,kAXRoleAttribute) as? String ?? ""
            let title=value(node,kAXTitleAttribute) as? String ?? ""
            let newPath=title.isEmpty ? path : path+[title]
            if role == kAXMenuItemRole && !title.isEmpty {
                let char=value(node,kAXMenuItemCmdCharAttribute) as? String ?? ""
                let code=(value(node,kAXMenuItemCmdVirtualKeyAttribute) as? NSNumber)?.intValue
                if let key=keyName(char:char,code:code), !key.isEmpty {
                    let mods=Modifiers.accessibility((value(node,kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0)
                    let enabled=(value(node,kAXEnabledAttribute) as? NSNumber)?.boolValue
                    result.append(Shortcut(id:"menu:\(profile):\(newPath.joined(separator:"/")):\(key):\(mods.rawValue)",profile:profile,title:title,category:ShortcutFilter.category(for:title),strokes:[KeyStroke(key:key,modifiers:mods)],source:.menu,enabled:enabled,note:path.joined(separator:" › ")))
                }
            }
            if let children=value(node,kAXChildrenAttribute) as? [AXUIElement] {
                for child in children { if Date() >= deadline { partial=true;break }; visit(child,path:newPath,depth:depth+1) }
            }
        }
        visit(menu,path:[],depth:0)
        let endWindow=element(value(app,kAXFocusedWindowAttribute))
        let endFocus=element(value(app,kAXFocusedUIElementAttribute))
        func equal(_ a:AXUIElement?,_ b:AXUIElement?)->Bool {
            if let a,let b{return CFEqual(a,b)}
            return a==nil && b==nil
        }
        guard equal(startWindow,endWindow),equal(focus,endFocus) else {
            return ScanResult(shortcuts:[],message:L10n.text("Il contesto è cambiato durante la lettura. Richiama il pannello per aggiornare."),complete:false,menuAvailable:true)
        }
        return ScanResult(shortcuts:ShortcutFilter.unique(result),message:partial ? L10n.text("Lettura parziale: alcuni menu non hanno risposto in tempo.") : L10n.format("%d scorciatoie lette dai menu · altri comandi possono dipendere dal contesto.",result.count),complete:!partial,focusedRole:role,frame:frame,menuAvailable:true)
    }
    static func keyName(char: String, code: Int?) -> String? {
        let special:[Int:String]=[36:"Return",48:"Tab",49:"Space",51:"Delete",53:"Escape",76:"Enter",117:"ForwardDelete",123:"Left",124:"Right",125:"Down",126:"Up",115:"Home",119:"End",116:"PageUp",121:"PageDown",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20"]
        let chars:[String:String]=["\r":"Return","\t":"Tab"," ":"Space","\u{1b}":"Escape","\u{8}":"Delete","\u{7f}":"Delete","\u{f700}":"Up","\u{f701}":"Down","\u{f702}":"Left","\u{f703}":"Right"]
        if let key=chars[char] { return key }
        if !char.isEmpty, let scalar=char.unicodeScalars.first, scalar.value < 0xf700 { return char.uppercased() }
        if let code, let key=special[code] { return key }
        return nil
    }
}
