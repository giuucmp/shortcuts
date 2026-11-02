import SwiftUI
import ShortcutCore

enum StudioMode:String,CaseIterable {case catalog="Catalogo",practice="Esercizi",hidden="Nascoste"}
final class StudioState:ObservableObject {
    @Published var mode:StudioMode = .catalog
    @Published var practice=PracticeSession()
    @Published var practiceIncludeSystem=false
    @Published var profile="current"
    @Published var query=""
    @Published var favoriteOnly=false
    @Published var filter:Modifiers=[]
    @Published var showUnparsed=false
}
