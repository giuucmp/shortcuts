import AppKit
import SwiftUI
import ShortcutCore

struct CompactShortcutRow:View {
    @Environment(\.colorScheme) private var colorScheme
    let shortcut:Shortcut
    let secondary:Bool
    let study:Bool
    let scale:Double
    var showContext=true
    @ObservedObject var model:AppModel
    private var detail:String? {ShortcutText.detail(shortcut)}
    private var keyWidth:CGFloat {
        let font=NSFont.monospacedSystemFont(ofSize:(secondary ? 9:10)*scale,weight:.semibold)
        return min((secondary ? 95:138)*scale,ceil((ShortcutText.keys(shortcut) as NSString).size(withAttributes:[.font:font]).width)+2*scale)
    }
    var body:some View {
        let important=model.options.highlightDaily && (ShortcutPresentation.dailyRank(shortcut) != nil || ShortcutImportance.level(shortcut) == .essential)
        let context=ShortcutText.context(shortcut)
        HStack(spacing:4*scale) {
            if study {
                Button {model.toggleVisibility(shortcut)} label: {
                    Image(systemName:model.options.isHidden(shortcut) ? "eye.slash":"eye")
                        .font(.system(size:9*scale)).foregroundStyle(Color(nsColor:ShortcutSecondary.color)).frame(width:14*scale,height:16*scale).contentShape(Rectangle())
                }.buttonStyle(.plain).help(L10n.text(model.options.isHidden(shortcut) ? "Ripristina azione":"Nascondi azione"))
                    .accessibilityLabel(L10n.format(model.options.isHidden(shortcut) ? "Ripristina: %@":"Nascondi: %@",ShortcutText.title(shortcut)))
                Button {model.toggleFavorite(shortcut)} label: {
                    Image(systemName:shortcut.isFavorite(in:model.favorites) ? "star.fill":"star")
                        .font(.system(size:9*scale)).foregroundStyle(shortcut.isFavorite(in:model.favorites) ? Color.orange:Color(nsColor:ShortcutSecondary.color))
                        .frame(width:14*scale,height:16*scale).contentShape(Rectangle())
                }.buttonStyle(.plain).help(L10n.text("Preferito")).accessibilityLabel(L10n.format("Preferito: %@",ShortcutText.title(shortcut)))
            }
            VStack(alignment:.leading,spacing:0) {
                Text(L10n.text(ShortcutText.title(shortcut))).font(.system(size:(secondary ? 9:10)*scale,weight:important && !secondary ? .semibold:.regular)).lineLimit(1)
                if showContext,let detail,!detail.isEmpty {
                    HStack(spacing:3*scale) {
                        if context.kind == .conditional {Image(systemName:"circle.lefthalf.filled").font(.system(size:7*scale))}
                        Text(L10n.text(detail)).font(.system(size:8*scale)).lineLimit(1)
                    }.foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            Text(L10n.text(ShortcutText.keys(shortcut)))
                .font(.system(size:(secondary ? 9:10)*scale,weight:important ? .semibold:.medium,design:.monospaced))
                .multilineTextAlignment(.trailing).lineLimit(2).minimumScaleFactor(0.8)
                .frame(width:keyWidth,alignment:.trailing)
                .foregroundStyle(important && !secondary ? Color(nsColor:ShortcutAccent.color(dark:colorScheme == .dark)):(secondary ? Color(nsColor:ShortcutSecondary.color):Color.primary))
                .accessibilityLabel(L10n.format("Tasti: %@",ShortcutText.keys(shortcut)))
        }
        .opacity(shortcut.enabled == false ? 0.45:1)
        .help([ShortcutText.title(shortcut),ShortcutText.keys(shortcut),context.summary,context.explanation,L10n.text(shortcut.sourceLabel),L10n.format("Titolo originale: %@",shortcut.title)].filter{!$0.isEmpty}.joined(separator:"\n"))
        .contextMenu {
            Button(L10n.text(model.options.isHidden(shortcut) ? "Ripristina azione":"Nascondi azione")){model.toggleVisibility(shortcut)}
            Button(L10n.text(shortcut.isFavorite(in:model.favorites) ? "Rimuovi dai preferiti":"Aggiungi ai preferiti")){model.toggleFavorite(shortcut)}
            if let url=shortcut.sourceURL,let link=URL(string:url) {Button(L10n.text("Apri la fonte")){NSWorkspace.shared.open(link)}}
        }
    }
}

struct ShortcutGroupCard:View {
    let group:ShortcutBoardLayout.Group
    let fit:ShortcutBoardLayout.Fit
    let study:Bool
    @ObservedObject var model:AppModel
    var body:some View {
        let scale=fit.scale
        let secondary=fit.secondary
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:5*scale) {
                Image(systemName:ShortcutPresentation.symbol(for:group.category))
                    .font(.system(size:(secondary ? 9:11)*scale,weight:.semibold))
                    .frame(width:14*scale)
                Text(L10n.text(group.category)).font(.system(size:(secondary ? 9:11)*scale,weight:.bold)).lineLimit(1)
                if group.partCount>1 {Text(L10n.text("\(group.part+1)/\(group.partCount)")).font(.system(size:8*scale)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))}
                Spacer(minLength:2)
                Text(L10n.text("\(group.shortcuts.count)")).font(.system(size:8*scale,weight:.medium,design:.rounded))
                    .monospacedDigit().foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            }
            .frame(height:ShortcutBoardLayout.headerHeight(secondary:secondary)*scale,alignment:.center)
            .overlay(alignment:.bottom) {Rectangle().fill(Color.primary.opacity(secondary ? 0.07:0.12)).frame(height:0.5)}
            ForEach(group.shortcuts) {shortcut in
                CompactShortcutRow(shortcut:shortcut,secondary:secondary,study:study,scale:scale,showContext:fit.showContext,model:model)
                    .frame(height:(fit.showContext ? ShortcutBoardLayout.rowHeight(shortcut,secondary:secondary):(secondary ? 16:18))*scale)
            }
        }
        .padding(6*scale)
        .frame(width:fit.columnWidth,height:group.height*scale,alignment:.topLeading)
        .background(Color.primary.opacity(secondary ? 0.025:0.055),in:RoundedRectangle(cornerRadius:8*scale))
        .overlay {RoundedRectangle(cornerRadius:8*scale).strokeBorder(Color.primary.opacity(secondary ? 0.06:0.13),lineWidth:0.6)}
    }
}

struct CompactGrid:View {
    let fit:ShortcutBoardLayout.Fit
    let study:Bool
    @ObservedObject var model:AppModel
    var body:some View {
        HStack(alignment:.top,spacing:fit.gap) {
            ForEach(Array(fit.columns.enumerated()),id:\.offset) { _,column in
                VStack(alignment:.leading,spacing:fit.gap*fit.scale) {
                    ForEach(column.groups) {group in
                        ShortcutGroupCard(group:group,fit:fit,study:study,model:model)
                    }
                }.frame(width:fit.columnWidth,alignment:.topLeading)
            }
        }.frame(height:fit.height,alignment:.topLeading)
    }
}

struct ShortcutBoard:View {
    let layout:ShortcutBoardLayout.Board
    let study:Bool
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            if let fit=layout.application {CompactGrid(fit:fit,study:study,model:model)}
            if let fit=layout.system {
                VStack(alignment:.leading,spacing:2) {
                    HStack(spacing:6) {
                        Image(systemName:"desktopcomputer")
                        Text(L10n.text("macOS · in tutte le app")).fontWeight(.semibold)
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(height:0.5)
                    }.font(.system(size:9)).frame(height:14).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    CompactGrid(fit:fit,study:study,model:model).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                }
            }
        }.frame(maxWidth:.infinity,alignment:.topLeading)
    }
}

struct CompactShortcutSheet:View {
    let items:[Shortcut]
    @ObservedObject var model:AppModel
    var study=false
    var body:some View {
        GeometryReader {geometry in
            let layout=ShortcutBoardLayout.board(items,width:geometry.size.width+24,maximumContentHeight:geometry.size.height,favorites:model.favorites,textScale:model.options.textSize.scale)
            ShortcutBoard(layout:layout,study:study,model:model)
        }
    }
}

struct OverlayView:View {
    @ObservedObject var model:AppModel
    var layout:ShortcutBoardLayout.Board?
    var contextLabel:String?
    var body:some View {
        let items=layout.map{[$0.application,$0.system].compactMap{$0}.flatMap(\.columns).flatMap(\.groups).flatMap(\.shortcuts)} ?? ShortcutFilter.match(model.panelItems,modifiers:model.modifiers)
        VStack(alignment:.leading,spacing:7) {
            HStack(alignment:.center,spacing:8) {
                Text(L10n.text(model.profileName)).font(.system(size:15,weight:.semibold)).lineLimit(1)
                Text(L10n.format("%d comandi",items.filter{!$0.isSystem}.count)).font(.system(size:9)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                Spacer(minLength:4)
                Text(L10n.text(model.modifiers.isEmpty ? "Tutti i tasti":model.modifiers.symbols))
                    .font(.system(size:model.modifiers.isEmpty ? 10:17,weight:.medium)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
            }.frame(height:22)
            if items.isEmpty {
                Text(L10n.text("Nessuna combinazione visibile con questi tasti.")).font(.system(size:11)).foregroundStyle(Color(nsColor:ShortcutSecondary.color))
                    .frame(height:28)
            } else if let layout {
                ShortcutBoard(layout:layout,study:false,model:model)
            } else {CompactShortcutSheet(items:items,model:model)}
            HStack(spacing:5) {
                Text(L10n.text(contextLabel ?? model.contextLabel)+" · "+L10n.text("◐ condizione d’uso"))
                Spacer(minLength:4)
                Text(L10n.text("Rilascia per chiudere"))
            }.font(.system(size:8.5)).foregroundStyle(Color(nsColor:ShortcutSecondary.color)).lineLimit(1).frame(height:10)
        }.padding(12).frame(maxHeight:.infinity,alignment:.topLeading).preferredColorScheme(model.options.theme.colorScheme)
    }
}
