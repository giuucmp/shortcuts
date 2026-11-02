import AppKit
import Carbon
import ApplicationServices
import ShortcutCore

final class EventMonitor {
    private var global:Any?;private var local:Any?;private var holdTimer:Timer?
    private var observers=[NSObjectProtocol]()
    private var installedWithTrust:Bool?
    private(set) var session=ModifierSession()
    let model:AppModel
    let panel:ShortcutPanel
    init(model:AppModel,panel:ShortcutPanel) {self.model=model;self.panel=panel}
    func start() {
        stop()
        let mask:NSEvent.EventTypeMask=[.flagsChanged,.keyDown,.leftMouseDown,.rightMouseDown,.otherMouseDown,.scrollWheel]
        global=NSEvent.addGlobalMonitorForEvents(matching:mask) { [weak self] e in self?.handle(e) }
        local=NSEvent.addLocalMonitorForEvents(matching:mask) { [weak self] e in
            self?.handle(e)
            return e // Observation only: never swallow, replace or synthesize input.
        }
        installedWithTrust=AXIsProcessTrusted()
        for name in [NSWorkspace.sessionDidResignActiveNotification,NSWorkspace.screensDidSleepNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.dismiss() })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in self?.dismiss() })
        model.onApplicationChange={ [weak self] in self?.dismiss() }
        model.onContextChange={ [weak self] in guard let self,self.panel.isVisible else{return};self.model.refresh(force:true) }
    }
    /// Independent of AppModel.trusted: a refresh may have updated that value
    /// before the permission timer gets its turn.
    @discardableResult func synchronizeAuthorization()->Bool {
        guard installedWithTrust != AXIsProcessTrusted() else{return false}
        start();return true
    }
    func stop() {
        if let global {NSEvent.removeMonitor(global)}
        if let local {NSEvent.removeMonitor(local)}
        global=nil;local=nil
        observers.forEach {NSWorkspace.shared.notificationCenter.removeObserver($0)};observers=[]
        dismiss()
    }
    func dismiss() {
        holdTimer?.invalidate();holdTimer=nil;session.reset()
        if !model.modifiers.isEmpty {model.modifiers=[]}
        panel.dismiss()
    }
    private var canObserveHold:Bool {
        !model.paused && !IsSecureEventInputEnabled() && NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
    func handle(_ event:NSEvent) {
        guard canObserveHold else{dismiss();return}
        if event.type == .flagsChanged {
            if session.modifiers.isEmpty,!HeldModifiers.fromEvent(event.modifierFlags).isEmpty {model.prepareForHold()}
            session.delay=UserDefaults.standard.object(forKey:"delay") as? Double ?? 0.35
            session.triggers=Modifiers(rawValue:UserDefaults.standard.object(forKey:"triggers") as? Int ?? Modifiers.all.rawValue)
            session.update(HeldModifiers.fromEvent(event.modifierFlags),at:ProcessInfo.processInfo.systemUptime)
            if session.modifiers.isEmpty {dismiss();return}
            ensureReleaseCheck()
            advanceHold()
        } else {
            // Clicks and typing continue to the underlying app immediately.
            session.pressKey();panel.dismiss()
            if session.modifiers.isEmpty {dismiss()}
        }
    }
    private func ensureReleaseCheck() {
        guard holdTimer==nil else{return}
        let timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in self?.advanceHold() }
        holdTimer=timer
        // Common modes keep release detection alive during menus and drag tracking.
        RunLoop.main.add(timer,forMode:.common)
    }
    private func advanceHold() {
        guard canObserveHold else{dismiss();return}
        let now=ProcessInfo.processInfo.systemUptime
        session.reconcileHeldModifiers(HeldModifiers.current,at:now)
        guard !session.modifiers.isEmpty else{dismiss();return}
        // The role probe runs off the main thread and has a bounded wait. A
        // released key or typed character still cancels the hold immediately.
        guard session.visible || !model.shouldWaitForFocus else{return}
        let wasVisible=session.visible
        session.tick(at:now)
        if model.modifiers != session.modifiers {model.modifiers=session.modifiers}
        guard session.canPresent(physicallyHeld:HeldModifiers.current) else{panel.dismiss();return}
        if !wasVisible {model.panelPresentations+=1;model.refresh()}
        if !panel.isVisible || panel.displayedModifiers != session.modifiers {panel.present(while:session)}
    }
}
