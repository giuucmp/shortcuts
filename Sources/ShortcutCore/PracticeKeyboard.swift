import Foundation

public struct PracticeKeyInput:Equatable {
    /// Key with no modifiers applied, translated using the current keyboard layout.
    public let key:String
    /// Character produced by the layout with Shift/Option, without Command/Control.
    public let characters:String
    public let modifiers:Modifiers
    public let isRepeat:Bool
    public init(key:String,characters:String?=nil,modifiers:Modifiers=[],isRepeat:Bool=false) {
        self.key=key;self.characters=characters ?? key;self.modifiers=modifiers;self.isRepeat=isRepeat
    }
    public var display:String {KeyStroke(key:key,modifiers:modifiers).display}
}

/// Keyboard drills intentionally exclude combinations macOS handles before an
/// app responder. This does not attempt to override user-defined global hotkeys.
public enum PracticeKeyboard {
    public enum Restriction:Equatable {case systemReserved,unsupported}
    public static func restriction(for item:Shortcut)->Restriction? {
        guard !item.strokes.isEmpty else{return .unsupported}
        for stroke in item.strokes {
            let key=normalizedKey(stroke.key),m=stroke.modifiers
            if key.range(of:"^F([1-9]|1[0-9]|2[0-4])$",options:.regularExpression) != nil {return .systemReserved}
            if m.contains(.function),!["Return","Enter","Delete","ForwardDelete","Left","Right","Up","Down","Home","End","PageUp","PageDown"].contains(key) {return .systemReserved}
            if key=="Tab",m.contains(.command) {return .systemReserved}
            if key=="Space",!m.intersection([.command,.control,.function]).isEmpty {return .systemReserved}
            if ["Up","Down","Left","Right","0","1","2","3","4","5","6","7","8","9"].contains(key),m.contains(.control),!m.contains(.command),!m.contains(.option),!m.contains(.function) {return .systemReserved}
            if key=="Q",m.contains(.command),!m.intersection([.control,.shift]).isEmpty {return .systemReserved}
            if key=="Escape",m.isSuperset(of:[.command,.option]) {return .systemReserved}
            if key=="D",m.isSuperset(of:[.command,.option]) {return .systemReserved}
            if ["3","4","5","6"].contains(key),m.isSuperset(of:[.command,.shift]) {return .systemReserved}
            if ["`","~"].contains(key),m.contains(.command) {return .systemReserved}
            if ["8","=","+","-"].contains(key),m.isSuperset(of:[.command,.option]) {return .systemReserved}
            let named=["Tab","Return","Enter","Escape","Space","Delete","ForwardDelete","Up","Down","Left","Right","Home","End","PageUp","PageDown"]
            guard named.contains(key) || (key.count==1 && !key.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains)) else{return .unsupported}
        }
        return nil
    }
    public static func matches(_ input:PracticeKeyInput,expected:KeyStroke)->Bool {
        let wanted=canonical(expected)
        let base=canonical(KeyStroke(key:input.key,modifiers:input.modifiers))
        if base==wanted {return true}
        let produced=canonical(KeyStroke(key:input.characters,modifiers:input.modifiers))
        if produced==wanted {return true}
        // Cmd+plus on a US layout needs Shift+=, whereas '+' is unshifted on
        // other layouts. Shift/Option can be layout requirements only when they produce that symbol.
        let isSymbol=wanted.key.count==1 && !wanted.key.unicodeScalars.contains(where:CharacterSet.alphanumerics.contains)
        return isSymbol && base.key != wanted.key && produced.key==wanted.key
            && produced.modifiers.isSuperset(of:wanted.modifiers)
            && produced.modifiers.subtracting(wanted.modifiers).subtracting([.shift,.option]).isEmpty
    }
    private static func canonical(_ stroke:KeyStroke)->KeyStroke {
        var key=normalizedKey(stroke.key),modifiers=stroke.modifiers
        let fnKeys=["Return":"Enter","Delete":"ForwardDelete","Left":"Home","Right":"End","Up":"PageUp","Down":"PageDown"]
        if modifiers.contains(.function),let translated=fnKeys[key] {key=translated;modifiers.remove(.function)}
        // macOS may preserve the Fn flag after translating a portable key.
        if ["Enter","ForwardDelete","Home","End","PageUp","PageDown"].contains(key) {modifiers.remove(.function)}
        return KeyStroke(key:key,modifiers:modifiers)
    }
    static func normalizedKey(_ key:String)->String {
        let aliases=["escape":"Escape","esc":"Escape","⎋":"Escape","space":"Space"," ":"Space","return":"Return","⏎":"Return","↩":"Return","enter":"Enter","⌅":"Enter","tab":"Tab","⇥":"Tab","backspace":"Delete","delete":"Delete","⌫":"Delete","forwarddelete":"ForwardDelete","⌦":"ForwardDelete","up":"Up","↑":"Up","down":"Down","↓":"Down","left":"Left","←":"Left","right":"Right","→":"Right","home":"Home","↖":"Home","end":"End","↘":"End","pageup":"PageUp","⇞":"PageUp","pagedown":"PageDown","⇟":"PageDown"]
        return aliases[key.lowercased()] ?? key.uppercased()
    }
}
