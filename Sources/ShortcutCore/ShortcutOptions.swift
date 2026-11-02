import Foundation

public enum ShortcutTextSize:String,Codable,CaseIterable {case compact="Compatto",standard="Standard",large="Grande"
    public var scale:Double {self == .compact ? 0.85:self == .large ? 1.18:1}
}
public enum ShortcutTheme:String,Codable,CaseIterable {case system="Automatico",light="Chiaro",dark="Scuro"}
public enum ShortcutBackground:String,Codable,CaseIterable {case glass="Liquid Glass",solid="Pieno"}
public enum ShortcutPosition:String,Codable,CaseIterable {case right="Destra",left="Sinistra"}
public struct ShortcutOptions:Codable,Equatable {
    public var hiddenKeys=Set<String>()
    public var showSystem=true
    public var contextualFiltering=true
    public var hideConditional=false
    public var hideUnavailable=false
    public var showContext=true
    public var highlightDaily=true
    public var textSize:ShortcutTextSize = .standard
    public var theme:ShortcutTheme = .system
    public var background:ShortcutBackground = .glass
    public var position:ShortcutPosition = .right
    public var language:AppLanguage = .system
    public init() {}
    private enum CodingKeys:String,CodingKey {case hiddenKeys,showSystem,contextualFiltering,hideConditional,hideUnavailable,showContext,highlightDaily,textSize,theme,background,position,language}
    public init(from decoder:Decoder) throws {
        self.init()
        let values=try decoder.container(keyedBy:CodingKeys.self)
        hiddenKeys=(try? values.decode(Set<String>.self,forKey:.hiddenKeys)) ?? hiddenKeys
        showSystem=(try? values.decode(Bool.self,forKey:.showSystem)) ?? showSystem
        contextualFiltering=(try? values.decode(Bool.self,forKey:.contextualFiltering)) ?? contextualFiltering
        hideConditional=(try? values.decode(Bool.self,forKey:.hideConditional)) ?? hideConditional
        hideUnavailable=(try? values.decode(Bool.self,forKey:.hideUnavailable)) ?? hideUnavailable
        showContext=(try? values.decode(Bool.self,forKey:.showContext)) ?? showContext
        highlightDaily=(try? values.decode(Bool.self,forKey:.highlightDaily)) ?? highlightDaily
        textSize=(try? values.decode(ShortcutTextSize.self,forKey:.textSize)) ?? textSize
        theme=(try? values.decode(ShortcutTheme.self,forKey:.theme)) ?? theme
        background=(try? values.decode(ShortcutBackground.self,forKey:.background)) ?? background
        position=(try? values.decode(ShortcutPosition.self,forKey:.position)) ?? position
        language=(try? values.decode(AppLanguage.self,forKey:.language)) ?? language
    }
    private func key(_ item:Shortcut)->String {
        if item.isSystem,!item.strokes.isEmpty {return "system|"+item.display}
        return item.profile+"|"+ShortcutPresentation.title(item).folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"it_IT"))
    }
    public func isHidden(_ item:Shortcut)->Bool {hiddenKeys.contains(key(item))}
    public mutating func hide(_ item:Shortcut) {hiddenKeys.insert(key(item))}
    public mutating func show(_ item:Shortcut) {hiddenKeys.remove(key(item))}
    public func visible(_ items:[Shortcut])->[Shortcut] {
        items.filter {item in
            !isHidden(item) && (showSystem || !item.isSystem) && (!hideUnavailable || item.enabled != false) && (!hideConditional || ShortcutPresentation.context(item).kind != .conditional)
        }
    }
}
