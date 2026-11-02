import AppKit
import SwiftUI
import ApplicationServices
import Carbon
import Combine
import ShortcutCore

final class AppDelegate:NSObject,NSApplicationDelegate,NSMenuDelegate {
    var model:AppModel!
    var panel:ShortcutPanel!
    var monitor:EventMonitor!
    var status:NSStatusItem!
    var statusMenu:NSMenu!
    var study:NSWindow?
    let studioState=StudioState()
    var preferences:NSWindow?
    var permissionTimer:Timer?
    private var appearanceUpdates:AnyCancellable?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        model=AppModel();panel=ShortcutPanel(model:model);monitor=EventMonitor(model:model,panel:panel)
        appearanceUpdates=model.$options.sink {[weak self] options in
            L10n.language=options.language
            if self?.status != nil {self?.configureMenus()}
            self?.study?.title=L10n.text("Scorciatoie · Studio")
            self?.preferences?.title=L10n.text("Scorciatoie · Impostazioni")
            self?.study?.appearance=options.theme.nativeAppearance
            self?.preferences?.appearance=options.theme.nativeAppearance
        }
        monitor.start()
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.autosaveName="Scorciatoie.MenuBar"
        status.behavior=[];status.isVisible=true
        if let button=status.button {
            if let icon=NSImage(systemSymbolName:"command.square",accessibilityDescription:L10n.text("Scorciatoie · Impostazioni")) {
                icon.isTemplate=true;icon.size=NSSize(width:17,height:17);button.image=icon
            } else {button.title="⌘"}
            button.toolTip=L10n.text("Scorciatoie · Impostazioni (clic destro: Studio e comandi)")
            button.setAccessibilityLabel(L10n.text("Scorciatoie · Apri impostazioni"))
            button.target=self;button.action=#selector(statusClicked(_:))
            button.sendAction(on:[.leftMouseUp,.rightMouseUp])
        }
        configureMenus()
        permissionTimer=Timer.scheduledTimer(withTimeInterval:2,repeats:true) { [weak self] _ in
            guard let self else{return}
            let trusted=AXIsProcessTrusted()
            if self.model.trusted != trusted {
                self.model.trusted=trusted
                if !trusted {self.monitor.dismiss()}
            }
            if self.monitor.synchronizeAuthorization() {self.model.refresh(force:true)}
            // Catalog browsing still works when menu access is unavailable. Close once on
            // revocation, not every two seconds while a catalog panel is being consulted.
            if self.panel.isVisible && IsSecureEventInputEnabled() {self.monitor.dismiss()}
        }
        // Launch quietly. Studio and Preferences open only through explicit menu actions.
    }
    private func configureMenus() {
        let menu=NSMenu();menu.delegate=self
        add("Impostazioni…",action:#selector(openPreferences),to:menu)
        add("Apri Studio e catalogo completo",action:#selector(openStudy),to:menu)
        menu.addItem(.separator())
        add("Aggiorna comandi dell’app",action:#selector(refresh),to:menu)
        add("Metti in pausa / riprendi",action:#selector(togglePause),to:menu)
        add("Consenti Accessibilità…",action:#selector(access),to:menu)
        menu.addItem(.separator())
        add("Importa scorciatoie personali…",action:#selector(importCustom),to:menu)
        add("Esporta copertura attuale…",action:#selector(exportCoverage),to:menu)
        add("Verifica menu delle app aperte…",action:#selector(auditMenus),to:menu)
        add(L10n.text("Esci da Scorciatoie"),action:#selector(quit),to:menu)
        statusMenu=menu
        let main=NSMenu()
        let appItem=NSMenuItem();let appMenu=NSMenu(title:"Scorciatoie")
        appItem.submenu=appMenu;main.addItem(appItem)
        add("Apri Studio",action:#selector(openStudy),to:appMenu)
        add("Impostazioni…",action:#selector(openPreferences),to:appMenu)
        add("Verifica menu delle app aperte…",action:#selector(auditMenus),to:appMenu)
        appMenu.addItem(.separator())
        let quitItem=NSMenuItem(title:L10n.text("Esci da Scorciatoie"),action:#selector(quit),keyEquivalent:"q");quitItem.target=self;appMenu.addItem(quitItem)
        let editItem=NSMenuItem();let edit=NSMenu(title:L10n.text("Modifica"));editItem.submenu=edit;main.addItem(editItem)
        for (title,selector,key) in [("Taglia",#selector(NSText.cut(_:)),"x"),("Copia",#selector(NSText.copy(_:)),"c"),("Incolla",#selector(NSText.paste(_:)),"v"),("Seleziona tutto",#selector(NSText.selectAll(_:)),"a")] {edit.addItem(NSMenuItem(title:L10n.text(title),action:selector,keyEquivalent:key))}
        NSApp.mainMenu=main
        status.button?.toolTip=L10n.text("Scorciatoie · Impostazioni (clic destro: Studio e comandi)")
        status.button?.setAccessibilityLabel(L10n.text("Scorciatoie · Apri impostazioni"))
    }
    func add(_ name:String,action:Selector,to menu:NSMenu) {let item=NSMenuItem(title:L10n.text(name),action:action,keyEquivalent:"");item.target=self;menu.addItem(item)}
    func menuWillOpen(_ menu:NSMenu) {model.trusted=AXIsProcessTrusted()}
    @objc func statusClicked(_ sender:NSStatusBarButton) {
        monitor.dismiss()
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            statusMenu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.minY),in:sender)
        } else {openPreferences()}
    }
    @objc func openStudy() {
        monitor.dismiss()
        if study == nil {
            let view=StudioView(model:model,state:studioState,useProfile:{[weak self] id in self?.model.useProfile(id)})
            let screen=NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
            let w=NSWindow(contentRect:NSRect(x:0,y:0,width:max(820,screen.width*0.92),height:max(620,screen.height*0.90)),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            w.title=L10n.text("Scorciatoie · Studio");w.appearance=model.options.theme.nativeAppearance;w.contentView=NSHostingView(rootView:view);w.isReleasedWhenClosed=false;w.center();study=w
        }
        NSApp.activate(ignoringOtherApps:true);study?.makeKeyAndOrderFront(nil)
    }
    @objc func openPreferences() {
        monitor.dismiss()
        if preferences == nil {
            let w=NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:570),styleMask:[.titled,.closable],backing:.buffered,defer:false)
            let view=PreferencesView(model:model,state:PreferenceState(),manageHidden:{[weak self] in
                guard let self else{return};self.studioState.mode = .hidden;self.studioState.query="";self.studioState.filter=[];self.studioState.favoriteOnly=false;self.openStudy()
            })
            w.title=L10n.text("Scorciatoie · Impostazioni");w.appearance=model.options.theme.nativeAppearance;w.contentView=NSHostingView(rootView:view);w.isReleasedWhenClosed=false;w.center();preferences=w
        }
        NSApp.activate(ignoringOtherApps:true);preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func refresh(){model.loadBindings();model.refresh(force:true)}
    @objc func togglePause(){model.paused.toggle();monitor.dismiss();status.button?.appearsDisabled=model.paused}
    @objc func access(){model.requestAccess()}
    @objc func quit(){NSApp.terminate(nil)}
    @objc func auditMenus() {
        let dialog=NSSavePanel();dialog.nameFieldStringValue="Verifica-menu.json";dialog.allowedContentTypes=[.json]
        guard dialog.runModal() == .OK,let url=dialog.url else{return}
        let apps=NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier}
        let presentations=model.panelPresentations
        DispatchQueue.global(qos:.utility).async {
            let rows=apps.map { app -> [String:Any] in
                let result=AccessibilityReader.scan(pid:app.processIdentifier,profile:app.bundleIdentifier ?? "unknown")
                return ["app":app.localizedName ?? "","bundleID":app.bundleIdentifier ?? "","menuShortcuts":result.shortcuts.count,"scanCompleted":result.complete,"message":result.message]
            }
            let report:[String:Any]=["accessibility":AXIsProcessTrusted(),"panelPresentationsThisSession":presentations,"apps":rows,"verifiedActionsExecuted":0]
            do {try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:url)
                DispatchQueue.main.async {let a=NSAlert();a.messageText=L10n.text("Verifica menu salvata");a.informativeText=L10n.format("Rilevate %d app. Il rapporto contiene conteggi e stato di lettura; non esegue alcun comando.",rows.count);a.runModal()}
            } catch {DispatchQueue.main.async{NSAlert(error:error).runModal()}}
        }
    }
    @objc func importCustom(){
        let p=NSOpenPanel();p.allowedContentTypes=[.json];p.allowsMultipleSelection=false
        if p.runModal() == .OK,let url=p.url {
            do {try model.importCustom(Data(contentsOf:url));openStudy()}catch{NSAlert(error:error).runModal()}
        }
    }
    @objc func exportCoverage(){
        let panel=NSSavePanel();panel.nameFieldStringValue="Copertura-scorciatoie.json";panel.allowedContentTypes=[.json]
        if panel.runModal() == .OK,let url=panel.url {
            let rows=model.catalog.profiles.map { p -> [String:Any] in
                let entries=model.catalog.shortcuts.filter{$0.profile==p.id}
                return ["app":p.name,"profile":p.id,"catalogRecords":entries.count,"normalized":entries.filter{!$0.strokes.isEmpty}.count,"note":p.note,"sources":p.sources,"liveVerified":false]
            }
            do {try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:url)}catch{NSAlert(error:error).runModal()}
        }
    }
}
if CommandLine.arguments.contains("--diagnose") {
    let catalog=try Catalog.loadBundled()
    let apps=NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular}
    var report:[String:Any]=["accessibility":AXIsProcessTrusted(),"catalogEntries":catalog.shortcuts.count,"profiles":catalog.profiles.count,"runningApps":apps.map{["name":$0.localizedName ?? "","bundle":$0.bundleIdentifier ?? "","pid":$0.processIdentifier]}]
    if let finder=apps.first(where:{$0.bundleIdentifier=="com.apple.finder"}) {
        let scan=AccessibilityReader.scan(pid:finder.processIdentifier,profile:"finder")
        report["finderMenuProbe"]=["menuAvailable":scan.menuAvailable,"shortcuts":scan.shortcuts.count,"complete":scan.complete,"message":scan.message]
    }
    print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
} else {
    let app=NSApplication.shared;let delegate=AppDelegate();app.delegate=delegate
    withExtendedLifetime(delegate) {app.run()}
}
