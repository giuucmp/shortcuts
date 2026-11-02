import AppKit
import SwiftUI
import ApplicationServices
import ShortcutCore

final class AppModel: ObservableObject {
    let catalog: Catalog
    @Published var activeName="Finder"
    @Published var activeBundle="com.apple.finder"
    @Published var activeVersion=""
    @Published var modifiers: Modifiers=[]
    @Published var live=[Shortcut]()
    @Published var bindingReport=BindingReport()
    @Published var custom=[Shortcut]()
    @Published var scanMessage="I menu verranno letti quando attivi un’app."
    @Published var scanning=false
    @Published var trusted=AXIsProcessTrusted()
    @Published var menuAvailable=false
    @Published var focusedRole: String?
    @Published var activeContext=ActiveContext()
    @Published var favorites:Set<String>
    @Published var practiceProgress=[String:PracticeProgress]()
    @Published var options=ShortcutOptions() {
        didSet {
            L10n.language=options.language
            if let data=try? JSONEncoder().encode(options){UserDefaults.standard.set(data,forKey:"shortcutOptions")}
            if oldValue.language != options.language {loadBindings();refresh(force:true)}
        }
    }
    @Published var paused=false
    @Published var overrideProfile: String?
    @Published var bindingMessage=""
    @Published var catalogError: String?
    @Published var panelPresentations=0
    var frame: CGRect?
    var activePID: pid_t=0
    var generation=ScanGeneration()
    private let bindingQueue=DispatchQueue(label:"it.scorciatoie.bindings",qos:.utility)
    private let scanQueue=DispatchQueue(label:"it.scorciatoie.accessibility",qos:.userInitiated)
    private let focusQueue=DispatchQueue(label:"it.scorciatoie.focus",qos:.userInitiated,attributes:.concurrent)
    private var focusReadiness=FocusReadiness()
    var shouldWaitForFocus:Bool {focusReadiness.isWaiting(at:ProcessInfo.processInfo.systemUptime)}
    private var contextObserver:AXObserver?
    private var observedPID:pid_t=0
    private var observers=[NSObjectProtocol]()
    private var lastScan: Date = .distantPast
    var onApplicationChange:(()->Void)?
    var onContextChange:(()->Void)?
    var canReadMenus:Bool {trusted || menuAvailable}
    var profileID:String { overrideProfile ?? catalog.profile(for:activeBundle)?.id ?? "live:\(activeBundle)" }
    var profileName:String { overrideProfile.flatMap { p in catalog.profiles.first { $0.id==p }?.name }.map { "\(L10n.text(activeName)) · \(L10n.text($0))" } ?? L10n.text(activeName) }
    var activeItems:[Shortcut] {
        let base=catalog.records(for:profileID)
        let merged=ShortcutFilter.merge(catalog:BindingImport.apply(ShortcutFilter.merge(catalog:base,actual:live),report:bindingReport),actual:custom.filter{$0.profile==profileID || $0.isSystem})
        return merged+ContextualShortcuts.textInputSupplements(catalog.shortcuts,profile:profileID,existing:merged,context:activeContext)
    }
    var panelItems:[Shortcut] {
        // Resolve availability before filtering; never resurrect a disabled menu via a catalog duplicate.
        let items=options.visible(ShortcutFilter.forDisplay(activeItems,favorites:favorites))
        return options.contextualFiltering ? ContextualShortcuts.visible(items,in:activeContext):items
    }
    var contextLabel:String {options.contextualFiltering ? activeContext.label:"Catalogo dell’app"}
    init() {
        do { catalog=try Catalog.loadBundled() } catch { catalog=Catalog.empty;catalogError=L10n.format("Catalogo non leggibile: %@",error.localizedDescription) }
        favorites=Set(UserDefaults.standard.stringArray(forKey:"favorites") ?? [])
        if let data=UserDefaults.standard.data(forKey:"shortcutOptions"),let saved=try? JSONDecoder().decode(ShortcutOptions.self,from:data){options=saved}
        L10n.language=options.language
        if let data=UserDefaults.standard.data(forKey:"practiceProgress"),let saved=try? JSONDecoder().decode([String:PracticeProgress].self,from:data){practiceProgress=saved}
        if let data=UserDefaults.standard.data(forKey:"customShortcuts"),let saved=try? JSONDecoder().decode([Shortcut].self,from:data){custom=saved}
        let nc=NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] n in
            guard let app=n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else{return};self?.activate(app)
        })
        if let app=NSWorkspace.shared.frontmostApplication { activate(app) }
    }
    func activate(_ app:NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else{return}
        let changed=app.processIdentifier != activePID
        if changed { onApplicationChange?();overrideProfile=nil;_ = generation.advance();focusReadiness.cancel();live=[];focusedRole=nil;activeContext=ActiveContext();frame=nil;menuAvailable=false;lastScan = .distantPast }
        activePID=app.processIdentifier;activeBundle=app.bundleIdentifier ?? "unknown";activeName=app.localizedName ?? "App"
        activeVersion=app.bundleURL.flatMap { Bundle(url:$0)?.infoDictionary?["CFBundleShortVersionString"] as? String } ?? ""
        if changed { observeContext();probeFocus();loadBindings();refresh(force:true) }
    }
    private func observeContext() {
        if let old=contextObserver {CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(old),.defaultMode)}
        contextObserver=nil;observedPID=activePID
        guard canReadMenus,activePID>0 else{return}
        var observer:AXObserver?
        let status=AXObserverCreate(activePID,{ _,element,notification,pointer in
            guard let pointer else{return}
            let model=Unmanaged<AppModel>.fromOpaque(pointer).takeUnretainedValue()
            var pid:pid_t=0;AXUIElementGetPid(element,&pid)
            guard pid==model.activePID else{return}
            model.invalidateContext()
        },&observer)
        guard status == .success,let observer else{return}
        let element=AXUIElementCreateApplication(activePID)
        let pointer=Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer,element,kAXFocusedWindowChangedNotification as CFString,pointer)
        AXObserverAddNotification(observer,element,kAXFocusedUIElementChangedNotification as CFString,pointer)
        contextObserver=observer
        CFRunLoopAddSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.defaultMode)
    }
    func invalidateContext() {
        _ = generation.advance();scanning=false
        // Menu names/bindings remain useful, but availability belongs to the old context.
        live=live.map{var item=$0;item.enabled=nil;return item}
        focusedRole=nil;activeContext=ActiveContext();frame=nil;lastScan = .distantPast
        probeFocus()
        scanMessage="Contesto cambiato: aggiorno al prossimo richiamo."
        onContextChange?()
    }
    func prepareForHold() {probeFocus()}
    private func probeFocus() {
        guard activePID>0 else{return}
        let pid=activePID,bundle=activeBundle,previous=activeContext,token=focusReadiness.begin(at:ProcessInfo.processInfo.systemUptime)
        activeContext=ActiveContext()
        focusQueue.async {[weak self] in
            let result=ContextReader.read(pid:pid,bundle:bundle)
            DispatchQueue.main.async {
                guard let self,self.activePID==pid,self.focusReadiness.finish(token) else{return}
                self.focusedRole=result.role;self.activeContext=result.context
                if previous != result.context {
                    _ = self.generation.advance();self.scanning=false;self.lastScan = .distantPast
                    self.live=self.live.map{var item=$0;item.enabled=nil;return item}
                }
            }
        }
    }
    func refresh(force:Bool=false) {
        trusted=AXIsProcessTrusted()
        if canReadMenus && contextObserver==nil {observeContext()}
        guard !scanning || force else{return}
        guard force || Date().timeIntervalSince(lastScan)>=2 else{return}
        let pid=activePID;let profile=profileID;let token=generation.advance()
        scanning=true
        scanQueue.async { [weak self] in
            let result=AccessibilityReader.scan(pid:pid,profile:profile)
            DispatchQueue.main.async {
                guard let self,self.generation.accepts(token),self.activePID==pid,self.profileID==profile else{return}
                if result.complete || !result.shortcuts.isEmpty {self.live=result.shortcuts}
                else {self.live=self.live.map{var item=$0;item.enabled=nil;return item}}
                self.scanMessage=result.message
                // The separate structural probe owns focus facts, not this slower menu scan.
                self.frame=result.frame;self.scanning=false;self.menuAvailable=result.menuAvailable
                if result.complete {self.lastScan=Date()}
                self.migrateFavorites()
                if self.menuAvailable && self.contextObserver==nil {self.observeContext()}
            }
        }
    }
    func loadBindings() {
        let profile=profileID; let pid=activePID
        bindingReport=BindingReport()
        bindingQueue.async { [weak self] in
            let result=BindingSources.load(profile:profile)
            DispatchQueue.main.async {
                guard let self,self.profileID==profile,self.activePID==pid else{return}
                self.bindingReport=result.report;self.bindingMessage=result.message
                self.migrateFavorites()
            }
        }
    }
    func useProfile(_ id:String?) { overrideProfile=id;live=[];lastScan = .distantPast;loadBindings();refresh(force:true) }
    func items(for id:String)->[Shortcut] { id=="current" || id==profileID ? activeItems : ShortcutFilter.merge(catalog:catalog.records(for:id),actual:custom.filter{$0.profile==id || $0.isSystem}) }
    private func migrateFavorites() {
        guard !favorites.isEmpty else{return}
        let migrated=FavoriteSelection.migrated(favorites,using:ShortcutFilter.forDisplay(activeItems))
        if migrated != favorites {favorites=migrated;UserDefaults.standard.set(Array(favorites),forKey:"favorites")}
    }
    func toggleFavorite(_ item:Shortcut) {favorites=FavoriteSelection.toggling(item,in:favorites);UserDefaults.standard.set(Array(favorites),forKey:"favorites")}
    func toggleVisibility(_ item:Shortcut) {if options.isHidden(item){options.show(item)}else{options.hide(item)}}
    func recordPractice(_ item:Shortcut,remembered:Bool) {
        var progress=PracticeProgress.latest(for:item,in:practiceProgress) ?? PracticeProgress()
        progress.record(remembered:remembered)
        for id in item.knownIDs {practiceProgress[id]=progress}
        if let data=try? JSONEncoder().encode(practiceProgress){UserDefaults.standard.set(data,forKey:"practiceProgress")}
    }
    func importCustom(_ data:Data) throws {
        let report=try BindingImport.custom(data)
        guard report.shortcuts.allSatisfy({s in s.profile==profileID || catalog.profiles.contains{$0.id==s.profile}}) else{throw CocoaError(.fileReadCorruptFile)}
        let ids=Set(report.shortcuts.map(\.id));custom=custom.filter{!ids.contains($0.id)}+report.shortcuts
        UserDefaults.standard.set(try JSONEncoder().encode(custom),forKey:"customShortcuts")
    }
    func requestAccess() {
        let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        trusted=AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
extension Catalog {
    static var empty: Catalog { try! JSONDecoder().decode(Catalog.self,from:Data("{\"schemaVersion\":1,\"generated\":\"\",\"profiles\":[],\"shortcuts\":[]}".utf8)) }
}
