import Foundation

/// One lookup per physical hold. Async scans cannot shuffle a populated panel.
/// A menu-only app may fill its initially empty app section once.
public struct PanelSnapshot {
    public private(set) var items:[Shortcut]
    public private(set) var favorites:Set<String>
    private var mayFillApplication:Bool
    public var awaitsApplication:Bool {mayFillApplication}
    public init(items:[Shortcut],modifiers:Modifiers,favorites:Set<String>=[]) {
        self.items=items
        self.favorites=favorites
        mayFillApplication = !ShortcutFilter.match(items,modifiers:modifiers).contains{!$0.isSystem}
    }
    @discardableResult public mutating func acceptFirstApplicationResult(_ incoming:[Shortcut],modifiers:Modifiers,favorites:Set<String>=[])->Bool {
        guard mayFillApplication,ShortcutFilter.match(incoming,modifiers:modifiers).contains(where:{!$0.isSystem}) else{return false}
        items=incoming;self.favorites=favorites;mayFillApplication=false
        return true
    }
}
