import AppKit
import ObjectiveC.runtime
import ShortcutCore

// Test-only activation fixture. The actual process is prohibited from activation,
// and this window is never ordered or made key. Only these getter responses are
// simulated; all responder methods below come from the production source copy.
private var simulatedActive=false
private final class ActivationFixture:NSObject {
    @objc func simulatedIsActive()->Bool {simulatedActive}
}
private final class HiddenPracticeWindow:NSWindow {
    var simulatedKey=false
    override var isKeyWindow:Bool {simulatedKey}
    override var canBecomeKey:Bool {true}
}
private final class NextResponder:NSResponder {
    var keyDownCount=0,keyUpCount=0,flagsCount=0
    override func keyDown(with event:NSEvent) {keyDownCount+=1}
    override func keyUp(with event:NSEvent) {keyUpCount+=1}
    override func flagsChanged(with event:NSEvent) {flagsCount+=1}
}
private final class MenuActions:NSObject {
    var quitRequests=0,closeRequests=0
    @objc func requestedQuit(_ sender:Any?) {quitRequests+=1}
    @objc func requestedClose(_ sender:Any?) {closeRequests+=1}
}
@main struct Checks {
    @MainActor static func main() {
        let app=NSApplication.shared
        let policyAccepted=app.setActivationPolicy(.prohibited)
        guard app.activationPolicy() == .prohibited else {
            fputs("Cannot validate AppKit activation policy inside this sandbox. Run this isolated harness from Terminal.\n",stderr)
            exit(2)
        }
        _ = policyAccepted
        let activeMethod=class_getInstanceMethod(NSApplication.self,#selector(getter:NSApplication.isActive))!
        let fixtureMethod=class_getInstanceMethod(ActivationFixture.self,#selector(ActivationFixture.simulatedIsActive))!
        let original=method_setImplementation(activeMethod,method_getImplementation(fixtureMethod))
        defer {method_setImplementation(activeMethod,original)}
        var checks=0
        func check(_ value:@autoclosure ()->Bool,_ message:String) {
            checks+=1
            guard value() else {fputs("FAIL native: \(message)\n",stderr);exit(1)}
        }
        let window=HiddenPracticeWindow(contentRect:NSRect(x:0,y:0,width:500,height:200),styleMask:[.borderless],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false
        let container=NSView(frame:window.contentRect(forFrameRect:window.frame))
        let capture=PracticeCaptureView(frame:NSRect(x:0,y:0,width:300,height:100))
        let other=NSTextField(frame:NSRect(x:0,y:120,width:100,height:30))
        container.addSubview(capture);container.addSubview(other);window.contentView=container
        let next=NextResponder();capture.nextResponder=next
        var inputs=[PracticeKeyInput](),held=[(String,Bool)](),active=[Bool]()
        var session=PracticeSession(items:[Shortcut(id:"quit",profile:"test",title:"Quit",category:"File",strokes:[KeyStroke(key:"Q",modifiers:.command)],source:.catalog)])
        capture.onInput={inputs.append($0);_ = session.submit($0)}
        capture.onHeldChange={held.append(($0,$1))}
        capture.onActiveChange={active.append($0)}
        func event(_ type:NSEvent.EventType = .keyDown,_ key:String="q",_ code:UInt16=12,_ modifiers:NSEvent.ModifierFlags = .command,_ repeatKey:Bool=false)->NSEvent {
            NSEvent.keyEvent(with:type,location:.zero,modifierFlags:modifiers,timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,characters:key,charactersIgnoringModifiers:key,isARepeat:repeatKey,keyCode:code)!
        }
        let actions=MenuActions(),menu=NSMenu(title:"Harness")
        let quit=NSMenuItem(title:"Test Quit",action:#selector(MenuActions.requestedQuit(_:)),keyEquivalent:"q");quit.target=actions;quit.keyEquivalentModifierMask = .command
        let close=NSMenuItem(title:"Test Close",action:#selector(MenuActions.requestedClose(_:)),keyEquivalent:"w");close.target=actions;close.keyEquivalentModifierMask = .command
        menu.addItem(quit);menu.addItem(close);app.mainMenu=menu
        check(!capture.isCapturing,"Initially disarmed")
        check(!capture.accessibilityPerformPress(),"Cannot arm while app/window inactive")
        check(!capture.performKeyEquivalent(with:event()),"Inactive CmdQ passes through")
        capture.keyDown(with:event())
        check(next.keyDownCount==1,"Inactive keyDown forwarded to next responder")
        check(inputs.isEmpty,"Inactive input not captured")
        simulatedActive=true;window.simulatedKey=true
        check(!capture.performKeyEquivalent(with:event()),"Active window alone does not arm capture")
        check(capture.accessibilityPerformPress(),"Explicit activation arms hidden fixture")
        check(window.firstResponder === capture,"Capture owns first responder after explicit activation")
        check(active.last==true,"Activation callback")
        check(window.performKeyEquivalent(with:event(.keyDown,"q",12,.command,true)),"Repeated CmdQ is consumed")
        check(inputs.count==1 && inputs[0].isRepeat,"Repeated event delivered with repeat flag")
        check(!session.solved && session.mistakeCount==0,"Repeat does not solve or penalize a fresh drill")
        capture.keyUp(with:event(.keyUp,"q",12,[]))
        check(window.performKeyEquivalent(with:event()),"Window routes CmdQ to capture and consumes it")
        check(inputs.count==2 && inputs.last?.modifiers == .command,"Exactly one additional CmdQ input emitted")
        check(session.solved,"Native CmdQ input solves real core practice session")
        check(actions.quitRequests==0,"Consumed CmdQ did not reach menu action")
        check(held.last?.1==false,"Pressed chord is not released")
        capture.keyUp(with:event(.keyUp,"q",12,[]))
        check(held.last?.0=="" && held.last?.1==true,"keyUp publishes full release")
        check(window.performKeyEquivalent(with:event(.keyDown,"w",13)),"Window routes CmdW to capture and consumes it")
        check(inputs.count==3,"CmdW emitted exactly once")
        check(actions.closeRequests==0,"Consumed CmdW did not reach menu action")
        let beforeDirectKeys=inputs.count
        capture.keyDown(with:event());capture.keyDown(with:event(.keyDown,"w",13))
        check(inputs.count==beforeDirectKeys+2,"Direct CmdQ/CmdW keyDown are captured")
        check(next.keyDownCount==1,"Direct command keyDown does not leak to next responder")
        check(actions.quitRequests==0 && actions.closeRequests==0,"Direct command keyDown cannot execute menu actions")
        capture.keyUp(with:event(.keyUp,"q",12,[]))
        capture.keyUp(with:event(.keyUp,"w",13,[]))
        capture.keyDown(with:event(.keyDown,"c",8,[.command,.shift]))
        check(inputs.last?.modifiers == [.command,.shift],"keyDown retains modifiers")
        capture.keyDown(with:event(.keyDown,"c",8,[.command,.shift],true))
        check(inputs.last?.isRepeat==true,"Native repeat flag preserved for core to ignore")
        check(session.answered==0,"Held/repeated key never advances session by itself")
        capture.keyUp(with:event(.keyUp,"c",8,[]))
        capture.flagsChanged(with:event(.flagsChanged,"",56,.shift))
        check(held.last?.0=="⇧" && held.last?.1==false,"Modifier-only held feedback")
        capture.flagsChanged(with:event(.flagsChanged,"",56,[]))
        check(held.last?.1==true,"Modifier release feedback")
        capture.flagsChanged(with:event(.flagsChanged,"",63,.function))
        capture.keyDown(with:event(.keyDown,"",117,.function))
        check(inputs.last?.key=="ForwardDelete" && inputs.last?.modifiers.contains(.function)==true,"Fn Delete native translation retained")
        capture.keyUp(with:event(.keyUp,"",117,.function));capture.flagsChanged(with:event(.flagsChanged,"",63,[]))
        capture.flagsChanged(with:event(.flagsChanged,"",63,.function))
        capture.keyDown(with:event(.keyDown,"",76,.function))
        check(inputs.last?.key=="Enter" && inputs.last?.modifiers.contains(.function)==true,"Fn Return native Enter translation retained")
        check(PracticeKeyboard.matches(inputs.last!,expected:KeyStroke(key:"Return",modifiers:.function)),"Native Fn Enter matches portable Fn Return")
        capture.keyUp(with:event(.keyUp,"",76,.function));capture.flagsChanged(with:event(.flagsChanged,"",63,[]))
        check(held.last?.1==true,"Fn Return key/modifier release clears held state")
        let capturedBeforeBlur=inputs.count
        check(window.makeFirstResponder(other),"Another field can take focus")
        check(!capture.isCapturing && active.last==false,"Responder blur pauses capture")
        check(!window.performKeyEquivalent(with:event()),"CmdQ passes through after blur")
        check(menu.performKeyEquivalent(with:event()),"Passed-through CmdQ reaches normal menu routing")
        check(actions.quitRequests==1,"Normal menu action executed after blur")
        check(inputs.count==capturedBeforeBlur,"Blur does not record keys")
        capture.keyUp(with:event(.keyUp,"q",12,[]));capture.flagsChanged(with:event(.flagsChanged,"",56,[]))
        check(next.keyUpCount==1 && next.flagsCount==1,"Inactive keyUp and modifier events forward normally")
        check(capture.accessibilityPerformPress(),"Capture may be explicitly rearmed")
        capture.stop()
        check(!capture.isCapturing && window.firstResponder !== capture,"Stop disarms and releases responder")
        check(!capture.performKeyEquivalent(with:event(.keyDown,"w",13)),"CmdW passes through after stop")
        check(menu.performKeyEquivalent(with:event(.keyDown,"w",13)),"Passed-through CmdW reaches menu")
        check(actions.closeRequests==1,"Normal close action restored")
        check(capture.accessibilityPerformPress(),"Rearm before window notification")
        window.simulatedKey=false
        NotificationCenter.default.post(name:NSWindow.didResignKeyNotification,object:window)
        check(!capture.isCapturing && active.last==false,"Window deactivation pauses capture")
        check(!capture.accessibilityPerformPress(),"Cannot rearm a non-key window")
        window.simulatedKey=true
        check(capture.accessibilityPerformPress(),"Rearm before application notification")
        simulatedActive=false
        NotificationCenter.default.post(name:NSApplication.didResignActiveNotification,object:app)
        check(!capture.isCapturing && held.last?.1==true,"Application deactivation clears capture/held state")
        check(!capture.performKeyEquivalent(with:event()),"Inactive application passes shortcuts through")
        check(app.activationPolicy() == .prohibited,"Harness remains prohibited from activation")
        check(!window.isVisible,"Harness window was never displayed")
        capture.stop(notify:false);window.close()
        print("NATIVE PRACTICE PASS: \(checks) assertions")
        print("Boundary: key-window/application-active getters were simulated inside this process; direct NSWindow/NSView routing used production source. No window ordering, app activation, global event posting, event monitors, or taps. Actual OS dispatch/interception remains a live QA boundary.")
    }
}
