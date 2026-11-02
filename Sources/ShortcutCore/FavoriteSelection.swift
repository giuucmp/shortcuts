import Foundation

public enum FavoriteSelection {
    /// Migrate only identities we can actually resolve; retain unknown legacy ids.
    public static func migrated(_ saved:Set<String>,using items:[Shortcut])->Set<String> {
        var result=saved
        for item in items where !item.knownIDs.isDisjoint(with:saved) {
            result.subtract(item.knownIDs);result.insert(item.favoriteID)
        }
        return result
    }
    public static func toggling(_ item:Shortcut,in saved:Set<String>)->Set<String> {
        var result=migrated(saved,using:[item])
        if result.contains(item.favoriteID) {result.remove(item.favoriteID)} else {result.insert(item.favoriteID)}
        return result
    }
}
