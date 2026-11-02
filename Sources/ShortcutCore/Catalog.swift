import Foundation
public struct CatalogProfile: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var bundleIDs: [String]
    public var note: String
    public var sources: [String]
    public var parent: String?
}
public struct Catalog: Codable, Sendable {
    public var schemaVersion: Int
    public var generated: String
    public var profiles: [CatalogProfile]
    public var shortcuts: [Shortcut]
    public static func loadBundled() throws -> Catalog {
        guard let url = ShortcutResources.bundle.url(forResource:"catalog",withExtension:"json") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:url))
    }
    public func profile(for bundleID: String) -> CatalogProfile? { profiles.first { $0.bundleIDs.contains(bundleID) } }
    public func records(for id: String) -> [Shortcut] {
        let parent = profiles.first { $0.id == id }?.parent
        return shortcuts.filter { $0.profile == id || $0.profile == "system" || $0.profile == parent }.map { item in
            var s=item; if s.profile == parent { s.profile=id; s.id=id+":"+s.id }; return s
        }
    }
}
