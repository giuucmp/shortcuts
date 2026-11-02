import SwiftUI
import ShortcutCore

private final class PracticeInteraction:ObservableObject {
    @Published var captureActive=false
    @Published var heldKeys=""
    @Published var keysReleased=true
    @Published var lastResult:PracticeInputResult?
    @Published var lastInput=""
    var advanceTask:Task<Void,Never>?
    deinit {advanceTask?.cancel()}
}

struct PracticeView:View {
    @ObservedObject var model:AppModel
    @ObservedObject var state:StudioState
    let items:[Shortcut]
    @StateObject private var interaction=PracticeInteraction()
    private var includeSystem:Bool {state.profile=="system" || state.practiceIncludeSystem}
    private var prepared:PracticeSession {
        PracticeSession(items:items.filter{!model.options.isHidden($0)},favorites:model.favorites,progress:model.practiceProgress,includeSystem:includeSystem)
    }
    private func start(_ deck:[Shortcut]) {
        pause()
        interaction.lastResult=nil;interaction.lastInput=""
        state.practice=PracticeSession(items:deck.filter{!model.options.isHidden($0)},favorites:model.favorites,progress:model.practiceProgress,includeSystem:includeSystem)
    }
    private func pause() {
        interaction.advanceTask?.cancel();interaction.advanceTask=nil
        interaction.captureActive=false;interaction.heldKeys="";interaction.keysReleased=true
        state.practice.resetSequence()
        if case .stepMatched=interaction.lastResult {interaction.lastResult=nil}
    }
    private func record(_ answer:PracticeAnswer?) {
        if let answer {model.recordPractice(answer.item,remembered:answer.remembered)}
        interaction.lastResult=nil;interaction.lastInput=""
    }
    private func completeAnswer() {record(state.practice.advance())}
    private func scheduleAdvance() {
        interaction.advanceTask?.cancel();interaction.advanceTask=nil
        guard interaction.captureActive,interaction.keysReleased,state.practice.solved,let id=state.practice.current?.id else{return}
        interaction.advanceTask=Task { @MainActor in
            try? await Task.sleep(nanoseconds:650_000_000)
            guard !Task.isCancelled,interaction.captureActive,interaction.keysReleased,state.practice.solved,state.practice.current?.id==id else{return}
            completeAnswer()
            if state.practice.completed {pause()}
        }
    }
    private func input(_ value:PracticeKeyInput) {
        guard interaction.captureActive else{return}
        let result=state.practice.submit(value)
        guard result != .ignored else{return}
        interaction.lastInput=value.display.replacingOccurrences(of:"spazio",with:L10n.text("spazio"));interaction.lastResult=result
        scheduleAdvance()
    }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            if state.practice.current != nil {
                HStack {
                    Text(L10n.format("Comando %d di %d",state.practice.answered+1,state.practice.cards.count)).font(.headline)
                    Spacer()
                    Button(L10n.text("Interrompi")){pause()}.buttonStyle(.bordered).disabled(!interaction.captureActive)
                    Button(L10n.text("Termina sessione")){pause();state.practice=PracticeSession()}.buttonStyle(.plain)
                }
                ProgressView(value:Double(state.practice.answered),total:Double(state.practice.cards.count))
            }
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if state.practice.cards.isEmpty {introduction}
                    else if state.practice.completed {completion}
                    else if let item=state.practice.current {exercise(item)}
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
        }.padding(28).frame(maxWidth:760,maxHeight:.infinity,alignment:.topLeading)
            .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
            .onDisappear{pause()}
    }
    private var introduction:some View {
        VStack(alignment:.leading,spacing:18) {
            Image(systemName:"keyboard").font(.system(size:34)).foregroundStyle(Color.accentColor)
            Text(L10n.text("Cinque comandi, con le tue dita")).font(.title.weight(.semibold))
            Text(L10n.text("Leggi l’azione e premi la combinazione nell’area esercizio. Una risposta corretta al primo tentativo, senza suggerimenti, conta come ricordata.")).foregroundStyle(Color(nsColor:ShortcutSecondary.color)).fixedSize(horizontal:false,vertical:true)
            if state.profile != "system" {Toggle(L10n.text("Includi le scorciatoie macOS"),isOn:$state.practiceIncludeSystem)}
            let ready=prepared
            if !ready.cards.isEmpty {
                Button(L10n.format("Inizia %d esercizi",ready.cards.count)){start(items)}.buttonStyle(.borderedProminent).controlSize(.large)
                Text(L10n.text("Partiamo dai comandi da ripassare e dai preferiti. I progressi restano su questo Mac.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            } else {
                Text(L10n.text("Nessun comando adatto con questi filtri. Scegli un’app o aggiungi preferiti.")).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            }
            exclusions(ready)
            Text(L10n.text("La tastiera si attiva solo quando fai clic nell’area esercizio. Interrompi o passa a un’altra finestra per metterla in pausa.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }
    }
    private var completion:some View {
        VStack(alignment:.leading,spacing:18) {
            Image(systemName:"checkmark.circle").font(.system(size:36)).foregroundStyle(.green)
            Text(L10n.text("Sessione completata")).font(.title.weight(.semibold))
            Text(L10n.format("%d su %d al primo tentativo",state.practice.rememberedCount,state.practice.cards.count)).font(.title2)
            Text(state.practice.reviewCards.isEmpty ? L10n.text("Tutte le combinazioni erano corrette, senza aiuti."):L10n.format("%d comandi da ripassare: errori, suggerimenti o esercizi saltati.",state.practice.reviewCards.count)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            HStack {
                if !state.practice.reviewCards.isEmpty {Button(L10n.text("Ripassa questi comandi")){start(state.practice.reviewCards)}.buttonStyle(.borderedProminent)}
                Button(L10n.text("Altri 5 esercizi")){start(items)}.buttonStyle(.bordered)
            }
            Button(L10n.text("Torna al catalogo")){pause();state.mode = .catalog}
        }
    }
    private func exercise(_ item:Shortcut)->some View {
        VStack(alignment:.leading,spacing:18) {
            VStack(alignment:.leading,spacing:16) {
                HStack {
                    Label(ShortcutText.group(item),systemImage:ShortcutPresentation.symbol(for:ShortcutPresentation.group(item))).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    Spacer()
                    Button {pause();model.toggleFavorite(item)} label: {
                        Image(systemName:item.isFavorite(in:model.favorites) ? "star.fill":"star").foregroundStyle(item.isFavorite(in:model.favorites) ? Color.orange:Color(nsColor:ShortcutSecondary.color))
                    }.buttonStyle(.plain).help(L10n.text("Preferito")).accessibilityLabel(L10n.format("Preferito: %@",ShortcutText.title(item)))
                }
                Text(L10n.text("Quale combinazione usi per…")).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                Text(ShortcutText.title(item)).font(.system(size:25,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                let context=ShortcutText.context(item)
                Label(context.summary,systemImage:context.kind == .conditional ? "circle.lefthalf.filled":context.kind == .availableNow ? "checkmark.circle":"circle").font(.callout).help(context.explanation)
                if item.strokes.count>1 {
                    Text(L10n.format("Sequenza: passaggio %d di %d",min(state.practice.strokeIndex+1,item.strokes.count),item.strokes.count)).font(.callout.weight(.medium))
                    Text(L10n.text("Premi una combinazione alla volta, nell’ordine. Un errore fa ripartire la sequenza.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                }
                captureSurface
                feedback
                if state.practice.revealed {
                    Divider()
                    Text(ShortcutText.keys(item)).font(.system(size:28,weight:.medium,design:.monospaced)).foregroundStyle(Color.accentColor).fixedSize(horizontal:false,vertical:true)
                    Text(L10n.text("Con il suggerimento, questo comando resterà da ripassare. Prova comunque a premere i tasti.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                }
                HStack {
                    if !state.practice.solved {
                        Button(L10n.text("Mostra suggerimento")){pause();state.practice.reveal()}.disabled(state.practice.revealed)
                        Button(L10n.text("Salta e ripassa")){pause();record(state.practice.skip())}
                    } else if !interaction.captureActive {
                        Button(L10n.text("Continua")){completeAnswer()}.buttonStyle(.borderedProminent)
                    }
                }
            }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
                .background(Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                .overlay{RoundedRectangle(cornerRadius:16).strokeBorder(Color.primary.opacity(0.08),lineWidth:1)}
            Text(L10n.text("Nell’area attiva i tasti vengono controllati senza eseguire il comando dell’app. Le scorciatoie globali personalizzate possono avere precedenza.")).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            exclusions(state.practice)
        }
    }
    private var captureSurface:some View {
        PracticeKeyCapture(active:interaction.captureActive,onActiveChange:{active in
            if active {interaction.captureActive=true;scheduleAdvance()} else {pause()}
        },onInput:input,onHeldChange:{text,released in
            interaction.heldKeys=text;interaction.keysReleased=released;scheduleAdvance()
        })
        .frame(height:114)
        .background(interaction.captureActive ? Color.accentColor.opacity(0.09):Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
        .overlay {
            VStack(spacing:10) {
                Label(L10n.text(interaction.captureActive ? "Tastiera attiva · premi la combinazione":"Fai clic qui per iniziare"),systemImage:interaction.captureActive ? "keyboard.fill":"cursorarrow.click")
                    .font(.callout.weight(.semibold))
                Text(interaction.heldKeys.isEmpty ? L10n.text("Nessun tasto premuto"):interaction.heldKeys).font(.system(size:21,weight:.medium,design:.monospaced)).foregroundStyle(interaction.heldKeys.isEmpty ? Color(nsColor:ShortcutSecondary.color):Color.primary)
            }.padding(12).allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay{RoundedRectangle(cornerRadius:12).strokeBorder(interaction.captureActive ? Color.accentColor:Color.primary.opacity(0.15),lineWidth:interaction.captureActive ? 2:1).allowsHitTesting(false)}
    }
    @ViewBuilder private var feedback:some View {
        if state.practice.solved {
            Label(L10n.text(interaction.captureActive ? "Corretto! Rilascia tutti i tasti per continuare.":"Corretto! Premi Continua quando vuoi."),systemImage:"checkmark.circle.fill").foregroundStyle(.green)
        } else if case .incorrect=interaction.lastResult {
            Label(L10n.format("Hai premuto %@. Non corrisponde: controlla i modificatori e riprova.",interaction.lastInput),systemImage:"arrow.counterclockwise.circle").foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true)
        } else if case let .stepMatched(completed,total)=interaction.lastResult {
            Label(L10n.format("Passaggio %d di %d corretto. Premi il successivo.",completed,total),systemImage:"checkmark.circle").foregroundStyle(.green)
        } else {
            Text(L10n.text(interaction.captureActive ? "Puoi premere i modificatori prima del tasto. I tasti tenuti premuti contano una sola volta.":"In pausa: fai clic nell’area per attivare la tastiera.")).font(.callout).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }
    }
    @ViewBuilder private func exclusions(_ session:PracticeSession)->some View {
        if session.excludedReservedCount>0 {
            Label(L10n.format("%d combinazioni riservate escluse dagli esercizi: cambio app, screenshot, blocco schermo, Mission Control e comandi di sistema o hardware.",session.excludedReservedCount),systemImage:"info.circle").font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color)).fixedSize(horizontal:false,vertical:true)
        }
        if session.excludedUnsupportedCount>0 {
            Text(L10n.format("%d combinazioni non riconosciute escluse dagli esercizi.",session.excludedUnsupportedCount)).font(.caption).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
        }
    }
}
