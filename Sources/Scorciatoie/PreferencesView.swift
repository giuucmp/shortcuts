import SwiftUI
import ShortcutCore

final class PreferenceState:ObservableObject {
    @Published var section=0
    @Published var delay:Double=UserDefaults.standard.object(forKey:"delay") as? Double ?? 0.35
    @Published var triggers:Int=UserDefaults.standard.object(forKey:"triggers") as? Int ?? Modifiers.all.rawValue
}
struct PreferencesView:View {
    @ObservedObject var model:AppModel
    @ObservedObject var state:PreferenceState
    let manageHidden:()->Void
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            Text(L10n.text("Come vuoi usare Shortcuts?")).font(.title2.weight(.semibold))
            Picker(L10n.text("Sezione impostazioni"),selection:$state.section) {
                Text(L10n.text("Aspetto")).tag(0);Text(L10n.text("Comandi")).tag(1);Text(L10n.text("Richiamo")).tag(2)
            }.pickerStyle(.segmented)
            Group {
                if state.section==0 {appearance}
                else if state.section==1 {visibility}
                else {triggers}
            }
            Spacer(minLength:0)
            Text(L10n.text("Le modifiche si salvano automaticamente su questo Mac.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }.padding(28).frame(width:620,height:570).preferredColorScheme(model.options.theme.colorScheme)
    }
    private var appearance:some View {
        VStack(alignment:.leading,spacing:12) {
            Picker(L10n.text("Lingua"),selection:$model.options.language) {
                ForEach(AppLanguage.allCases,id:\.self){Text($0.label).tag($0)}
            }.pickerStyle(.segmented).accessibilityIdentifier("language-picker")
            Picker(L10n.text("Dimensione del testo"),selection:$model.options.textSize) {
                ForEach(ShortcutTextSize.allCases,id:\.self){Text(L10n.text($0.rawValue)).tag($0)}
            }.pickerStyle(.segmented)
            Text(L10n.text("Il pannello adatta le colonne e il testo per mostrare tutte le scorciatoie scelte senza scroll.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            Picker(L10n.text("Tema"),selection:$model.options.theme) {
                ForEach(ShortcutTheme.allCases,id:\.self){Text(L10n.text($0.rawValue)).tag($0)}
            }.pickerStyle(.segmented)
            Picker(L10n.text("Sfondo del pannello"),selection:$model.options.background) {
                ForEach(ShortcutBackground.allCases,id:\.self){Text(L10n.text($0.rawValue)).tag($0)}
            }.pickerStyle(.segmented)
            Picker(L10n.text("Posizione del pannello"),selection:$model.options.position) {
                ForEach(ShortcutPosition.allCases,id:\.self){Text(L10n.text($0.rawValue)).tag($0)}
            }.pickerStyle(.segmented)
            Toggle(L10n.text("Evidenzia i comandi quotidiani"),isOn:$model.options.highlightDaily)
            Toggle(L10n.text("Mostra le note di contesto nel pannello"),isOn:$model.options.showContext)
            Text(L10n.text("Lo sfondo rispetta anche Riduci trasparenza e Aumenta contrasto di macOS.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }
    }
    private var visibility:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(L10n.text("Nel pannello")).font(.headline)
            Toggle(L10n.text("Adatta i comandi a quello che sto facendo"),isOn:$model.options.contextualFiltering)
            Text(L10n.text("Usa la zona attiva e lo stato dei menu. I comandi interni di terminale e browser compaiono solo quando la zona è riconosciuta. Studio conserva tutto il catalogo.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            Toggle(L10n.text("Mostra le scorciatoie macOS"),isOn:$model.options.showSystem)
            Toggle(L10n.text("Nascondi i comandi con condizioni d’uso"),isOn:$model.options.hideConditional)
            if !model.options.contextualFiltering {Toggle(L10n.text("Nascondi i comandi non disponibili ora"),isOn:$model.options.hideUnavailable)}
            Text(L10n.text("Le condizioni includono selezioni, appunti e modalità specifiche. Per nascondere una sola azione, usa l’occhio in Studio.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            Divider()
            Text(L10n.format("%d azioni nascoste",model.options.hiddenKeys.count)).font(.headline)
            Text(L10n.text("Le azioni nascoste vengono escluse dal pannello e dagli esercizi. Il catalogo conserva i dati per poterle ripristinare.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            HStack {
                Button(L10n.text("Gestisci in Studio")){manageHidden()}.buttonStyle(.borderedProminent)
                Button(L10n.text("Ripristina tutte")){model.options.hiddenKeys=[]}.disabled(model.options.hiddenKeys.isEmpty)
            }
        }
    }
    private var triggers:some View {
        VStack(alignment:.leading,spacing:13) {
            Text(L10n.text("Tieni premuto uno dei tasti attivi per vedere il pannello.")).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            HStack(spacing:16) {
                ForEach([Modifiers.command,.option,.control,.shift,.function],id:\.rawValue) {flag in
                    Toggle(L10n.text(flag.symbols),isOn:Binding(get:{Modifiers(rawValue:state.triggers).contains(flag)},set:{on in
                        var m=Modifiers(rawValue:state.triggers);if on{m.insert(flag)}else{m.remove(flag)}
                        state.triggers=m.rawValue;UserDefaults.standard.set(m.rawValue,forKey:"triggers")
                    }))
                }
            }
            Divider()
            Text(L10n.format("Attesa prima di aprire: %.2f s",state.delay))
            Slider(value:Binding(get:{state.delay},set:{state.delay=$0;UserDefaults.standard.set($0,forKey:"delay")}),in:0...1.5,step:0.05)
            Text(L10n.text("Shift da solo attende almeno 0,7 secondi. Se digiti un carattere, l’apertura viene annullata fino al rilascio.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            Text(L10n.text("I tasti singoli e le sequenze sono in Studio: clic destro sull’icona ⌘ nella barra dei menu.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }
    }
}
