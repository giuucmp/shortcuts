import AppKit
import SwiftUI
import Combine
import Carbon
import ShortcutCore

final class OverlayHostingView:NSHostingView<OverlayView> {
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {false}
}
final class ShortcutPanel:NSPanel {
    let model:AppModel
    private var host:OverlayHostingView!
    private var updates:AnyCancellable?
    private var displayObserver:NSObjectProtocol?
    private var anchorTop:CGFloat?
    private var anchoredScreen:NSScreen?
    private var snapshot:PanelSnapshot?
    private var snapshotContext=""
    private var renderedModifiers:Modifiers?
    private var renderedBounds:NSRect?
    private var renderedOptions:ShortcutOptions?
    private var appliedSurface=""
    private(set) var displayedModifiers:Modifiers=[]
    override var canBecomeKey:Bool {false}
    override var canBecomeMain:Bool {false}
    init(model:AppModel) {
        self.model=model
        super.init(contentRect:NSRect(x:0,y:0,width:640,height:700),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        level = .floating;isFloatingPanel=true;hidesOnDeactivate=false;isReleasedWhenClosed=false
        ignoresMouseEvents=true;acceptsMouseMovedEvents=false;isRestorable=false
        collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        backgroundColor = .clear;isOpaque=false;hasShadow=true
        host=OverlayHostingView(rootView:OverlayView(model:model));host.sizingOptions=[]
        host.autoresizingMask=[.width,.height]
        installSurface()
        displayObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) {[weak self] _ in self?.installSurface()}
        updates=model.objectWillChange.debounce(for:.milliseconds(45),scheduler:RunLoop.main).sink {[weak self] _ in
            guard let self,self.isVisible else{return}
            guard self.holdIsValid else{self.dismiss();return}
            self.updateLayout()
        }
        title=L10n.text("Shortcuts · Pannello")
        setAccessibilityLabel(L10n.text("Scorciatoie disponibili · tutte insieme"))
    }
    private func installSurface() {
        let bounds=NSRect(origin:.zero,size:frame.size)
        let opaque=model.options.background == .solid || NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        host.removeFromSuperview();host.frame=bounds
        if #available(macOS 26.0,*),!opaque {
            contentView=ShortcutGlassSurface(frame:bounds,content:host)
        } else if !opaque {
            let material=NSVisualEffectView(frame:bounds)
            material.material = .hudWindow;material.blendingMode = .behindWindow;material.state = .active
            material.wantsLayer=true;material.layer?.cornerRadius=18;material.layer?.masksToBounds=true
            material.addSubview(host);contentView=material
        } else {
            contentView=OpaquePanelSurface(frame:bounds,content:host)
        }
    }
    private var holdIsValid:Bool {
        !displayedModifiers.isEmpty && HeldModifiers.current.isSuperset(of:displayedModifiers) && !model.paused && !IsSecureEventInputEnabled() && NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
    func dismiss() {
        displayedModifiers=[];anchorTop=nil;anchoredScreen=nil;snapshot=nil
        renderedModifiers=nil;renderedBounds=nil;renderedOptions=nil
        orderOut(nil)
    }
    func present(while session:ModifierSession) {
        guard session.canPresent(physicallyHeld:HeldModifiers.current) else{dismiss();return}
        displayedModifiers=session.modifiers
        guard holdIsValid else{dismiss();return}
        updateLayout()
        // Recheck after layout: a released key must not leave a late presentation.
        guard holdIsValid else{dismiss();return}
        orderFrontRegardless()
    }
    private func updateLayout() {
        title=L10n.text("Shortcuts · Pannello")
        setAccessibilityLabel(L10n.text("Scorciatoie disponibili · tutte insieme"))
        var changedSnapshot=false
        if snapshot==nil {snapshot=PanelSnapshot(items:model.panelItems,modifiers:model.modifiers,favorites:model.favorites);snapshotContext=model.contextLabel;changedSnapshot=true}
        else if snapshot!.awaitsApplication {changedSnapshot=snapshot!.acceptFirstApplicationResult(model.panelItems,modifiers:model.modifiers,favorites:model.favorites)}
        var screen=NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation,$0.frame,false) } ?? NSScreen.main
        if let frame=model.frame, let primary=NSScreen.screens.first {
            let point=NSPoint(x:frame.midX,y:primary.frame.maxY-frame.midY)
            screen=NSScreen.screens.first { $0.frame.contains(point) } ?? screen
        }
        if let anchoredScreen,NSScreen.screens.contains(anchoredScreen) {screen=anchoredScreen}
        guard let screen else{return}
        anchoredScreen=screen
        let visible=screen.visibleFrame
        let surface=model.options.theme.rawValue+model.options.background.rawValue
        if appliedSurface != surface {
            appearance=model.options.theme.nativeAppearance
            installSurface();appliedSurface=surface
        }
        guard changedSnapshot || renderedModifiers != model.modifiers || renderedBounds != visible || renderedOptions != model.options else{return}
        let items=ShortcutFilter.match(snapshot?.items ?? [],modifiers:model.modifiers)
        let layout=ShortcutBoardLayout.preferred(items,maximumWidth:visible.width-24,maximumHeight:visible.height-24,favorites:snapshot?.favorites ?? [],textScale:model.options.textSize.scale,showContext:model.options.showContext)
        host.rootView=OverlayView(model:model,layout:layout,contextLabel:snapshotContext)
        renderedModifiers=model.modifiers;renderedBounds=visible;renderedOptions=model.options
        let top=min(visible.maxY-12,anchorTop ?? visible.midY+layout.height/2)
        let bottom=max(visible.minY+12,top-layout.height)
        anchorTop=bottom+layout.height
        let x=model.options.position == .left ? visible.minX+12:visible.maxX-layout.width-12
        setFrame(NSRect(x:x,y:bottom,width:layout.width,height:layout.height),display:true)
    }
    deinit {if let displayObserver {NSWorkspace.shared.notificationCenter.removeObserver(displayObserver)}}
}
