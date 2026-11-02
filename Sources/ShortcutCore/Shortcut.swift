import Foundation

public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1)
    public static let option = Self(rawValue: 2)
    public static let control = Self(rawValue: 4)
    public static let shift = Self(rawValue: 8)
    public static let function = Self(rawValue: 16)
    public static let all: Self = [.command,.option,.control,.shift,.function]
    public var symbols: String { [(Self.control,"⌃"),(.option,"⌥"),(.shift,"⇧"),(.command,"⌘"),(.function,"fn ")].filter { contains($0.0) }.map(\.1).joined() }
    public var count: Int { rawValue.nonzeroBitCount }
    public static func accessibility(_ value: Int) -> Self {
        var flags: Self = value & 8 == 0 ? .command : []
        if value & 1 != 0 { flags.insert(.shift) }
        if value & 2 != 0 { flags.insert(.option) }
        if value & 4 != 0 { flags.insert(.control) }
        return flags
    }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(Int.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct KeyStroke: Codable, Hashable, Sendable {
    public var key: String
    public var modifiers: Modifiers
    public init(key: String, modifiers: Modifiers = []) { self.key = key; self.modifiers = modifiers }
    public var display: String {
        let names = ["Tab":"⇥","Return":"↩","Enter":"⌅","Escape":"esc","Space":"spazio","Delete":"⌫","ForwardDelete":"⌦","Up":"↑","Down":"↓","Left":"←","Right":"→","PageUp":"⇞","PageDown":"⇟","Home":"↖","End":"↘"]
        return modifiers.symbols + (names[key] ?? key.uppercased())
    }
}
public enum ShortcutSource: String, Codable, Sendable { case catalog, menu, personal, extensionBinding }
public struct Shortcut: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var profile: String
    public var title: String
    public var category: String
    public var strokes: [KeyStroke]
    public var context: String?
    public var section: String?
    public var source: ShortcutSource
    public var sourceURL: String?
    public var enabled: Bool?
    public var note: String?
    public var rawBinding: String?
    public var actionID: String?
    public var aliases:[String]?
    public var favoriteIdentity:String?
    public var knownIDs:Set<String> {Set([id]+(aliases ?? []))}
    public var favoriteID:String {favoriteIdentity ?? "favorite:v1:"+ShortcutFilter.displayIdentity(self)}
    public func isFavorite(in favorites:Set<String>)->Bool {!favorites.isEmpty && (favorites.contains(favoriteID) || favorites.contains(id) || (aliases?.contains(where:favorites.contains) ?? false))}
    public init(id: String, profile: String, title: String, category: String, strokes: [KeyStroke], context: String? = nil, section: String? = nil, source: ShortcutSource, sourceURL: String? = nil, enabled: Bool? = nil, note: String? = nil, rawBinding: String? = nil, actionID: String? = nil) {
        self.id=id; self.profile=profile; self.title=title; self.category=category; self.strokes=strokes; self.context=context; self.section=section; self.source=source; self.sourceURL=sourceURL; self.enabled=enabled; self.note=note; self.rawBinding=rawBinding; self.actionID=actionID
    }
    public var display: String { strokes.isEmpty ? (rawBinding ?? "Da verificare") : strokes.map(\.display).joined(separator: " → ") }
    public var isSystem: Bool { profile == "system" || SystemShortcutIdentity.info(self) != nil }
    public var sourceLabel: String {
        if note?.hasPrefix("Conflitto") == true {return "Personalizzazione da verificare"}
        switch source { case .menu: return enabled == false ? "Non disponibile ora" : "Dal menu"; case .personal: return "Personale"; case .extensionBinding: return "Estensione · condizionale"; case .catalog: return strokes.isEmpty ? "Combinazione da verificare" : "Da documentazione" }
    }
}
public enum ShortcutFilter {
    private struct EquivalentKey:Hashable {
        let profile:String
        let strokes:[KeyStroke]
        let context:String
        let identity:String
    }
    public static func forProfile(_ items: [Shortcut], profile: String) -> [Shortcut] { items.filter { $0.profile == profile || $0.isSystem } }
    public static func match(_ items: [Shortcut], modifiers: Modifiers, query: String = "") -> [Shortcut] {
        var bindingQuery=query.trimmingCharacters(in:.whitespacesAndNewlines)
        for (symbol,name) in [("⌘","cmd+"),("⇧","shift+"),("⌥","alt+"),("⌃","ctrl+")] {bindingQuery=bindingQuery.replacingOccurrences(of:symbol,with:name)}
        bindingQuery=bindingQuery.replacingOccurrences(of:#"\s*\+\s*"#,with:"+",options:.regularExpression)
        let keys=bindingQuery.contains("+") ? KeyBindingParser.parse(bindingQuery):[]
        return items.filter { item in
            let modifierMatch = modifiers.isEmpty || (item.strokes.first.map { $0.modifiers.isSuperset(of: modifiers) } ?? false)
            guard modifierMatch else{return false}
            if !keys.isEmpty {return item.strokes.starts(with:keys)}
            return query.isEmpty || "\(item.title) \(item.category) \(ShortcutText.title(item)) \(ShortcutText.group(item)) \(ShortcutPresentation.title(item)) \(ShortcutPresentation.group(item)) \(ShortcutText.context(item).summary) \(item.context ?? "") \(item.display)".localizedStandardContains(query)
        }.sorted { a,b in
            let ac = a.strokes.first?.modifiers == modifiers ? 0 : 1
            let bc = b.strokes.first?.modifiers == modifiers ? 0 : 1
            if ac != bc { return ac < bc }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
    public static func unique(_ items: [Shortcut]) -> [Shortcut] {
        var indexes=[String:Int](),result=[Shortcut]()
        for s in items {
            let key = "\(s.profile)|\(s.title.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:.current))|\(s.display)|\(s.context ?? "")|\(s.source == .menu ? "":s.note ?? "")"
            if let index=indexes[key] {result[index].aliases=Array(result[index].knownIDs.union(s.knownIDs)).sorted()}
            else {indexes[key]=result.count;result.append(s)}
        }
        return result
    }
    public static func merge(catalog: [Shortcut], actual: [Shortcut]) -> [Shortcut] {
        let names = Set(actual.map { "\($0.profile)|\($0.title.lowercased())|\($0.context ?? "")" })
        let actions = Set(actual.compactMap { s in s.actionID.map { "\(s.profile)|\($0)|\(s.context ?? "")" } })
        var byName=[EquivalentKey:[Shortcut]](),byAction=[EquivalentKey:[Shortcut]]()
        for item in catalog {
            byName[EquivalentKey(profile:item.profile,strokes:item.strokes,context:item.context ?? "",identity:item.title.lowercased()),default:[]].append(item)
            if let action=item.actionID {byAction[EquivalentKey(profile:item.profile,strokes:item.strokes,context:item.context ?? "",identity:action),default:[]].append(item)}
        }
        let linked=actual.map {item -> Shortcut in
            var result=item
            let named=byName[EquivalentKey(profile:item.profile,strokes:item.strokes,context:item.context ?? "",identity:item.title.lowercased())] ?? []
            let commanded=item.actionID.flatMap{byAction[EquivalentKey(profile:item.profile,strokes:item.strokes,context:item.context ?? "",identity:$0)]} ?? []
            let equivalents=named+commanded
            result.aliases=Array(equivalents.reduce(item.knownIDs){$0.union($1.knownIDs)}).sorted()
            result.favoriteIdentity=equivalents.first?.favoriteID ?? item.favoriteID
            return result
        }
        return unique(linked + catalog.filter { s in
            !names.contains("\(s.profile)|\(s.title.lowercased())|\(s.context ?? "")") && !(s.actionID.map { actions.contains("\(s.profile)|\($0)|\(s.context ?? "")") } ?? false)
        })
    }
    /// Collapse only equivalent displayed actions. Keep distinct bindings and
    /// declared conditions; availability from a live menu wins over a catalog.
    public static func displayIdentity(_ item:Shortcut)->String {
        func normalized(_ text:String)->String {
            text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"it_IT")).split(whereSeparator:{$0.isWhitespace}).joined(separator:" ")
        }
        let embedded=item.title.components(separatedBy:" (").dropFirst().joined(separator:" (")
        let condition=[item.context,embedded,item.source == .menu ? nil:item.note].compactMap{$0}.map(normalized).filter{!$0.isEmpty}
        let fields=[item.isSystem ? "system":item.profile,normalized(ShortcutPresentation.title(item)),item.display]+condition
        // Length-prefix components, so literal separators in titles/keys can't collide.
        return fields.map{"\($0.utf8.count):\($0)"}.joined()
    }
    public static func forDisplay(_ items:[Shortcut],favorites:Set<String>=[])->[Shortcut] {
        var indexes=[String:Int](),result=[Shortcut]()
        for item in items {
            let identity=displayIdentity(item)
            guard let index=indexes[identity] else {indexes[identity]=result.count;var row=item;row.favoriteIdentity=item.favoriteID;result.append(row);continue}
            let existing=result[index],ids=existing.knownIDs.union(item.knownIDs)
            let preferMenu=item.source == .menu && existing.source != .menu
            let preferFavorite=item.source == existing.source && item.isFavorite(in:favorites) && !existing.isFavorite(in:favorites)
            if preferMenu || preferFavorite {result[index]=item}
            result[index].aliases=Array(ids).sorted()
        }
        return result
    }
    public static func category(for title: String) -> String {ShortcutCategory.classify(title)}

}
public struct ScanGeneration: Sendable {
    private var value = 0
    public init() {}
    public mutating func advance() -> Int { value += 1; return value }
    public func accepts(_ token: Int) -> Bool { token == value }
}
