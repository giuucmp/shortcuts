import AppKit
import SwiftUI
import ShortcutCore

struct StudioView:View {
    @ObservedObject var model:AppModel
    @ObservedObject var state: StudioState
    let useProfile:(String?)->Void
    var body:some View {
        let base=ShortcutFilter.forDisplay(model.items(for:state.profile),favorites:model.favorites)
        let items=ShortcutFilter.match(base,modifiers:state.filter,query:state.query).filter{(!state.favoriteOnly || $0.isFavorite(in:model.favorites)) && (state.showUnparsed || !$0.strokes.isEmpty) && (state.mode == .hidden ? model.options.isHidden($0):!model.options.isHidden($0))}
        HSplitView {
            VStack(alignment:.leading,spacing:18) {
                Label("Shortcuts",systemImage:"command.square.fill").font(.title2.weight(.semibold))
                Text(L10n.text("Impara mentre lavori.")).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                Picker(L10n.text("Sezione"),selection:$state.mode) {
                    ForEach(StudioMode.allCases,id:\.self){Text(L10n.text($0.rawValue)).tag($0)}
                }.pickerStyle(.segmented)
                Picker(L10n.text("Applicazione"),selection:$state.profile) {
                    Text(L10n.format("App attiva · %@",model.activeName)).tag("current")
                    ForEach(model.catalog.profiles) {p in Text(L10n.text(p.name)).tag(p.id)}
                }.labelsHidden()
                VStack(alignment:.leading,spacing:8) {
                    Text(L10n.text("FILTRA PER TASTI")).font(.caption.weight(.semibold)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    HStack(spacing:6) {
                        ForEach([Modifiers.command,.option,.control,.shift,.function],id:\.rawValue) {m in
                            Button(L10n.text(m.symbols)) {if state.filter.contains(m){state.filter.remove(m)}else{state.filter.insert(m)}}.buttonStyle(.bordered).tint(state.filter.contains(m) ? .accentColor:.gray)
                        }
                    }
                    if !state.filter.isEmpty {Button(L10n.text("Mostra tutti i tasti")){state.filter=[]}.font(.caption)}
                }
                Toggle(L10n.text("Solo preferiti"),isOn:$state.favoriteOnly)
                Toggle(L10n.text("Includi voci da verificare"),isOn:$state.showUnparsed)
                Text(L10n.text("★ salva i preferiti · l’occhio nasconde un’azione. In Nascoste puoi recuperarla. Vale anche per macOS.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                Divider()
                if !model.canReadMenus {
                    if model.panelPresentations > 0 {Label(L10n.text("Richiamo del pannello rilevato"),systemImage:"checkmark.circle.fill").foregroundStyle(.green)}
                    Text(L10n.text("Il catalogo è disponibile")).font(.headline)
                    Text(L10n.text("Questa copia non riesce ancora a leggere i menu. Puoi già consultare il catalogo; se il pannello compare, il richiamo da tastiera funziona.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    Text(L10n.text(model.scanMessage)).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    Button(L10n.text("Apri Accessibilità")){model.requestAccess()}.buttonStyle(.borderedProminent)
                    Button(L10n.text("Ho abilitato l’accesso")){model.refresh(force:true)}
                } else {
                    Label(L10n.text(model.menuAvailable ? "Menu accessibili":"Accessibilità attiva"),systemImage:"checkmark.circle.fill").foregroundStyle(.green)
                    Text(L10n.text(model.scanMessage)).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    Text(L10n.text(model.bindingMessage)).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    Button(L10n.text("Aggiorna menu e personalizzazioni")){model.loadBindings();model.refresh(force:true)}
                }
                if ["claude-code","codex-cli","safari-inspector"].contains(state.profile) {
                    Button(L10n.format("Usa nel pannello per %@",model.activeName)){useProfile(state.profile)}
                    Text(L10n.text(state.profile == "safari-inspector" ? "Usa questo profilo mentre lavori in Web Inspector. Ripristina il riconoscimento automatico per tornare ai comandi di Safari.":"Seleziona il profilo del programma che stai usando nel terminale. Non viene letto il contenuto del terminale.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                }
                if model.overrideProfile != nil {Button(L10n.text("Ripristina riconoscimento automatico")){useProfile(nil)}}
                Spacer()
                Text(L10n.text("⌘  ⌥  ⌃  ⇧  fn\nTieni premuto un modificatore per aprire il pannello nell’app attiva.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            }.padding(24).frame(minWidth:265,idealWidth:285,maxWidth:320).background(Color(NSColor.controlBackgroundColor))
            VStack(alignment:.leading,spacing:0) {
                VStack(alignment:.leading,spacing:12) {
                    HStack {Text(L10n.text(state.profile=="current" ? model.profileName : model.catalog.profiles.first{$0.id==state.profile}?.name ?? "Catalogo")).font(.title2.weight(.semibold));Spacer();Text(L10n.text("\(items.count)")).font(.title3).foregroundStyle(Color(nsColor:ShortcutSecondary.color))}
                    TextField(L10n.text("Cerca un’azione, una categoria o una combinazione"),text:$state.query).textFieldStyle(.roundedBorder)
                    if let p=model.catalog.profiles.first(where:{$0.id==(state.profile=="current" ? model.profileID:state.profile)}) {Text(L10n.text(p.note)).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))}
                    if let error=model.catalogError {Text(L10n.text(error)).foregroundStyle(.red)}
                }.padding(16)
                Divider()
                if state.mode == .practice {PracticeView(model:model,state:state,items:items)}
                else if items.isEmpty {VStack(alignment:.leading,spacing:8){Text(L10n.text(state.mode == .hidden ? "Nessuna scorciatoia nascosta":"Nessun risultato")).font(.title2);Text(L10n.text(state.mode == .hidden ? "Non ci sono azioni nascoste per questa app e questi filtri. Puoi scegliere un’altra app dal menu laterale.":"Modifica la ricerca o rimuovi un filtro. Per le app senza catalogo dedicato, attivale e abilita Accessibilità per leggerne i menu.")).foregroundStyle(Color(nsColor:ShortcutSecondary.color))}.padding(24);Spacer()}
                else {CompactShortcutSheet(items:items,model:model,study:true).padding(.horizontal,18).padding(.vertical,12)}
            }.frame(minWidth:490,maxWidth:.infinity)
        }.frame(minWidth:820,minHeight:620)
        .onChange(of:state.profile){_ in state.practice=PracticeSession()}
        .onChange(of:state.filter){_ in state.practice=PracticeSession()}
        .onChange(of:state.query){_ in state.practice=PracticeSession()}
        .onChange(of:state.favoriteOnly){_ in state.practice=PracticeSession()}
        .onChange(of:state.practiceIncludeSystem){_ in state.practice=PracticeSession()}
        .onChange(of:model.profileID){_ in if state.profile=="current" {state.practice=PracticeSession()}}
        .onChange(of:model.options.hiddenKeys){_ in state.practice=PracticeSession()}
        .preferredColorScheme(model.options.theme.colorScheme)
    }
}
