import Foundation

public enum AppLanguage:String,Codable,CaseIterable,Sendable {
    case system,it,en
    public var label:String {switch self {case .system:return L10n.text("Lingua di sistema");case .it:return "Italiano";case .en:return "English"}}
    public static func preferredLanguage(in preferences:[String])->AppLanguage {
        let supported=Bundle.preferredLocalizations(from:["en","it"],forPreferences:preferences)
        return supported.first.flatMap(AppLanguage.init(rawValue:)) ?? .en
    }
    public var resolved:AppLanguage {
        guard self == .system else{return self}
        return Self.preferredLanguage(in:Locale.preferredLanguages)
    }
}

/// Translation is presentation only. Raw command titles, binding identities,
/// conditions and saved favorites never depend on the selected language.
public enum L10n {
    public struct Translation:Decodable {public let it:String;public let en:String}
    private static let lock=NSLock()
    private static var selection:AppLanguage = .system
    public static var language:AppLanguage {
        get {lock.lock();defer{lock.unlock()};return selection}
        set {lock.lock();selection=newValue;lock.unlock()}
    }
    public static var locale:Locale {Locale(identifier:language.resolved == .it ? "it_IT":"en_US")}
    public static let resourceNames=["catalog-a","catalog-b","catalog-extra","catalog-safari","ui","practice-ui"]
    public static let translations:[String:Translation] = {
        var result=[String:Translation]()
        for name in resourceNames {
            guard let url=ShortcutResources.bundle.url(forResource:name,withExtension:"json"),let data=try? Data(contentsOf:url),let rows=try? JSONDecoder().decode([String:Translation].self,from:data) else{continue}
            result.merge(rows){_,new in new}
        }
        return result
    }()
    private static func normalized(_ value:String)->String {
        value.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"…",with:"").replacingOccurrences(of:"...",with:"").folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
    }
    private static let aliases:[String:Translation] = {
        var result=[String:Translation]()
        for key in translations.keys.sorted() {
            guard let row=translations[key] else{continue}
            for value in [key,row.it,row.en] where result[normalized(value)] == nil {result[normalized(value)]=row}
        }
        return result
    }()
    public static func hasTranslation(_ source:String)->Bool {translations[source] != nil || aliases[normalized(source)] != nil}
    public static func text(_ source:String)->String {text(source,language:language)}
    public static func text(_ source:String,language:AppLanguage)->String {
        if let row=translations[source] ?? aliases[normalized(source)] {return language.resolved == .it ? row.it:row.en}
        // Translate our generated provenance while retaining the raw note in identities.
        for template in generatedNotes {
            let parts=template.components(separatedBy:"%@")
            guard source.hasPrefix(parts[0]),source.hasSuffix(parts[1]),source.count>=parts[0].count+parts[1].count,let row=translations[template] else{continue}
            let argument=String(source.dropFirst(parts[0].count).dropLast(parts[1].count))
            return String(format:language.resolved == .it ? row.it:row.en,argument)
        }
        return source
    }
    private static let generatedNotes=[
        "Assegnazione dichiarata dall’estensione %@; attivazione e condizione non verificabili da qui.",
        "Conflitto con una personalizzazione: disattivata quando %@. La condizione del catalogo non è nota.",
        "Conflitto con una personalizzazione condizionale: %@. Verifica nell’editor."
    ]
    public static func format(_ source:String,_ arguments:CVarArg...)->String {
        String(format:text(source),locale:locale,arguments:arguments)
    }
    public static func components(_ source:String)->String {
        if hasTranslation(source) {return text(source)}
        return source.components(separatedBy:" · ").map{text($0)}.joined(separator:" · ")
    }
}

public enum ShortcutText {
    public static func title(_ item:Shortcut)->String {L10n.text(ShortcutPresentation.title(item))}
    public static func group(_ item:Shortcut)->String {L10n.text(ShortcutPresentation.group(item))}
    public static func keys(_ item:Shortcut)->String {
        guard !item.strokes.isEmpty else{return L10n.text(item.rawBinding ?? "Da verificare")}
        return item.strokes.map {stroke in
            stroke.key == "Space" ? stroke.modifiers.symbols+L10n.text("spazio"):stroke.display
        }.joined(separator:" → ")
    }
    public static func context(_ item:Shortcut)->ShortcutContext {
        let original=ShortcutPresentation.context(item)
        return ShortcutContext(kind:original.kind,summary:L10n.components(original.summary),explanation:L10n.components(original.explanation))
    }
    public static func detail(_ item:Shortcut)->String? {
        let value=context(item)
        switch value.kind {case .general,.availableNow:return nil;default:return value.summary}
    }
}
