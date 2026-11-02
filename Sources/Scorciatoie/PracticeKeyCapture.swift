import AppKit
import CoreGraphics
import SwiftUI
import ShortcutCore

/// A responder confined to the explicit practice surface. It installs no event
/// monitors, taps, global hotkeys, or changes to application menu shortcuts.
struct PracticeKeyCapture:NSViewRepresentable {
    let active:Bool
    let onActiveChange:(Bool)->Void
    let onInput:(PracticeKeyInput)->Void
    let onHeldChange:(String,Bool)->Void
    func makeNSView(context:Context)->PracticeCaptureView {PracticeCaptureView()}
    func updateNSView(_ view:PracticeCaptureView,context:Context) {
        view.onActiveChange=onActiveChange;view.onInput=onInput;view.onHeldChange=onHeldChange
        view.setAccessibilityLabel(L10n.text("Area esercizio tastiera"))
        view.setAccessibilityHelp(L10n.text("Fai clic per attivare la tastiera. Usa Interrompi per uscire dall’esercizio."))
        if !active && view.isCapturing {view.stop(notify:false)}
    }
    static func dismantleNSView(_ view:PracticeCaptureView,coordinator:()) {view.stop(notify:false)}
}

final class PracticeCaptureView:NSView {
    var onActiveChange:((Bool)->Void)?
    var onInput:((PracticeKeyInput)->Void)?
    var onHeldChange:((String,Bool)->Void)?
    private(set) var isCapturing=false
    private var heldKeys=[UInt16:String]()
    private var releaseKeyCodes=[UInt16:[UInt16]]()
    private var heldModifiers:Modifiers=[]
    private var functionDown=false
    private var releaseTimer:Timer?
    private var observers=[NSObjectProtocol]()
    override var acceptsFirstResponder:Bool {true}
    private var hasCaptureFocus:Bool {isCapturing && window?.firstResponder === self && window?.isKeyWindow==true && NSApp.isActive}
    override init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        setAccessibilityElement(true);setAccessibilityRole(.button)
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) has not been implemented")}
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach{NotificationCenter.default.removeObserver($0)};observers=[]
        guard let window else {stop(notify:false);return}
        for name in [NSWindow.didResignKeyNotification,NSWindow.willCloseNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main){[weak self] _ in self?.stop()})
        }
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main){[weak self] _ in self?.stop()})
    }
    deinit {releaseTimer?.invalidate();observers.forEach{NotificationCenter.default.removeObserver($0)}}
    override func mouseDown(with event:NSEvent) {activate(modifiers:event.modifierFlags)}
    override func accessibilityPerformPress()->Bool {activate();return isCapturing}
    private func activate(modifiers:NSEvent.ModifierFlags=[]) {
        guard let window,window.isKeyWindow,NSApp.isActive else{return}
        guard window.makeFirstResponder(self) else{return}
        isCapturing=true;heldKeys=[:];releaseKeyCodes=[:];heldModifiers=HeldModifiers.fromEvent(modifiers);functionDown=heldModifiers.contains(.function)
        onActiveChange?(true);publishHeld()
    }
    override func resignFirstResponder()->Bool {stop(releaseFocus:false);return super.resignFirstResponder()}
    func stop(notify:Bool=true,releaseFocus:Bool=true) {
        let wasActive=isCapturing
        isCapturing=false;heldKeys=[:];releaseKeyCodes=[:];heldModifiers=[];functionDown=false
        releaseTimer?.invalidate();releaseTimer=nil
        if releaseFocus,window?.firstResponder === self {window?.makeFirstResponder(nil)}
        if notify && wasActive {onHeldChange?("",true);onActiveChange?(false)}
    }
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        guard hasCaptureFocus else{return super.performKeyEquivalent(with:event)}
        // NSWindow tries key equivalents before normal keyDown delivery. Returning
        // true here keeps Cmd+Q, Cmd+W, menu actions, and default buttons in the drill.
        consume(event);return true
    }
    override func keyDown(with event:NSEvent) {
        guard hasCaptureFocus else {
            if window?.firstResponder === self,[36,49,76].contains(event.keyCode) {activate(modifiers:event.modifierFlags)}
            else {super.keyDown(with:event)}
            return
        }
        consume(event)
    }
    override func keyUp(with event:NSEvent) {
        guard hasCaptureFocus else {super.keyUp(with:event);return}
        heldKeys.removeValue(forKey:event.keyCode);releaseKeyCodes.removeValue(forKey:event.keyCode);heldModifiers=modifiers(for:event)
        publishHeld()
    }
    override func flagsChanged(with event:NSEvent) {
        guard hasCaptureFocus else {super.flagsChanged(with:event);return}
        if event.keyCode==63 {functionDown=event.modifierFlags.contains(.function)}
        heldModifiers=modifiers(for:event);publishHeld();ensureReleaseCheck()
    }
    private func modifiers(for event:NSEvent)->Modifiers {
        var result=HeldModifiers.fromEvent(event.modifierFlags)
        // AppKit adds .function to arrows and navigation keys even without a
        // physical Fn press. Keep Fn only when its flagsChanged event was seen.
        if event.keyCode != 63 && Self.specialKeys[event.keyCode] != nil {
            if functionDown {result.insert(.function)} else {result.remove(.function)}
        }
        return result
    }
    private func consume(_ event:NSEvent) {
        guard event.type == .keyDown else{return}
        let special=Self.specialKeys[event.keyCode]
        let base=special ?? event.characters(byApplyingModifiers:[]) ?? event.charactersIgnoringModifiers ?? ""
        let shifted=special ?? event.characters(byApplyingModifiers:event.modifierFlags.intersection([.shift,.option])) ?? base
        guard !base.isEmpty else{return}
        heldModifiers=modifiers(for:event);heldKeys[event.keyCode]=base
        var releaseCodes=[event.keyCode]
        if functionDown,let portable=Self.portableKeys[event.keyCode] {releaseCodes.append(portable)}
        releaseKeyCodes[event.keyCode]=releaseCodes
        publishHeld()
        onInput?(PracticeKeyInput(key:base,characters:shifted,modifiers:heldModifiers,isRepeat:event.isARepeat))
        ensureReleaseCheck()
    }
    private func ensureReleaseCheck() {
        guard releaseTimer==nil else{return}
        // AppKit may omit keyUp for Command combinations. Check releases only
        // for keys already delivered to this focused responder; never discover
        // or collect keys pressed in another view or application.
        let timer=Timer(timeInterval:0.08,repeats:true){[weak self] _ in
            guard let self else{return}
            guard self.hasCaptureFocus else {self.stop();return}
            let released=self.heldKeys.keys.filter {code in
                !(self.releaseKeyCodes[code] ?? [code]).contains{CGEventSource.keyState(.combinedSessionState,key:CGKeyCode($0))}
            }
            let modifiers=HeldModifiers.current
            if !released.isEmpty || modifiers != self.heldModifiers {
                released.forEach{self.heldKeys.removeValue(forKey:$0);self.releaseKeyCodes.removeValue(forKey:$0)}
                self.heldModifiers=modifiers;self.functionDown=modifiers.contains(.function)
                self.publishHeld()
            }
            if self.heldKeys.isEmpty && self.heldModifiers.isEmpty {self.releaseTimer?.invalidate();self.releaseTimer=nil}
        }
        releaseTimer=timer;RunLoop.main.add(timer,forMode:.common)
    }
    private func publishHeld() {
        let keys=heldKeys.sorted{$0.key<$1.key}.map{KeyStroke(key:$0.value).display.replacingOccurrences(of:"spazio",with:L10n.text("spazio"))}.joined(separator:" + ")
        let display=heldModifiers.symbols+keys
        setAccessibilityValue(display.isEmpty ? L10n.text("Nessun tasto premuto"):display)
        onHeldChange?(display,heldKeys.isEmpty && heldModifiers.isEmpty)
    }
    private static let portableKeys:[UInt16:UInt16]=[76:36,117:51,115:123,119:124,116:126,121:125]
    private static let specialKeys:[UInt16:String]=[
        36:"Return",76:"Enter",48:"Tab",53:"Escape",49:"Space",51:"Delete",117:"ForwardDelete",
        123:"Left",124:"Right",125:"Down",126:"Up",115:"Home",119:"End",116:"PageUp",121:"PageDown",
        122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12"
    ]
}
