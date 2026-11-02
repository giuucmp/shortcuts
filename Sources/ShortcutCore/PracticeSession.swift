import Foundation

public struct PracticeProgress:Codable {
    public private(set) var confidence=0
    public private(set) var attempts=0
    public init() {}
    public mutating func record(remembered:Bool) {attempts+=1;confidence=remembered ? min(3,confidence+1):0}
    public static func latest(for item:Shortcut,in progress:[String:PracticeProgress])->PracticeProgress? {
        item.knownIDs.sorted().compactMap{progress[$0]}.max{a,b in a.attempts==b.attempts ? a.confidence>b.confidence:a.attempts<b.attempts}
    }
}
public enum PracticeInputResult:Equatable {
    case ignored,incorrect,stepMatched(completed:Int,total:Int),correct
}
public struct PracticeAnswer {
    public let item:Shortcut
    public let remembered:Bool
}
public struct PracticeSession {
    public let cards:[Shortcut]
    public let excludedReservedCount:Int
    public let excludedUnsupportedCount:Int
    public private(set) var answered=0
    public private(set) var revealed=false
    public private(set) var reviewCards=[Shortcut]()
    public private(set) var rememberedCount=0
    public private(set) var strokeIndex=0
    public private(set) var mistakeCount=0
    public private(set) var solved=false
    public var current:Shortcut? {answered<cards.count ? cards[answered]:nil}
    public var completed:Bool {!cards.isEmpty && answered==cards.count}
    public init(items:[Shortcut]=[],favorites:Set<String>=[],progress:[String:PracticeProgress]=[:],limit:Int=5,includeSystem:Bool=false) {
        var seen=Set<String>(),reserved=0,unsupported=0
        let eligible=items.filter {item in
            guard (includeSystem || !item.isSystem),item.enabled != false else{return false}
            let key=ShortcutPresentation.title(item).lowercased()+"|"+item.display+"|"+ShortcutPresentation.context(item).explanation
            guard seen.insert(key).inserted else{return false}
            if let restriction=PracticeKeyboard.restriction(for:item) {
                if restriction == .systemReserved {reserved+=1} else {unsupported+=1}
                return false
            }
            return true
        }
        excludedReservedCount=reserved;excludedUnsupportedCount=unsupported
        let ranked=ShortcutImportance.ordered(eligible,favorites:favorites).enumerated().sorted {a,b in
            let ac=PracticeProgress.latest(for:a.element,in:progress)?.confidence ?? 0,bc=PracticeProgress.latest(for:b.element,in:progress)?.confidence ?? 0
            return ac==bc ? a.offset<b.offset:ac<bc
        }.map(\.element)
        cards=Array(ranked.prefix(max(0,limit)))
    }
    public mutating func reveal() {if current != nil {revealed=true}}
    @discardableResult public mutating func submit(_ input:PracticeKeyInput)->PracticeInputResult {
        guard !input.isRepeat,!solved,let item=current else{return .ignored}
        guard PracticeKeyboard.matches(input,expected:item.strokes[strokeIndex]) else {
            mistakeCount+=1;strokeIndex=0;return .incorrect
        }
        strokeIndex+=1
        if strokeIndex==item.strokes.count {solved=true;return .correct}
        return .stepMatched(completed:strokeIndex,total:item.strokes.count)
    }
    /// Focus changes cancel an unfinished sequence without fabricating a mistake.
    public mutating func resetSequence() {if !solved {strokeIndex=0}}
    /// Called only after the capture surface has observed all keys released.
    @discardableResult public mutating func advance()->PracticeAnswer? {
        guard solved else{return nil}
        return finish(remembered:mistakeCount==0 && !revealed)
    }
    @discardableResult public mutating func skip()->PracticeAnswer? {finish(remembered:false)}
    private mutating func finish(remembered:Bool)->PracticeAnswer? {
        guard let item=current else{return nil}
        if remembered {rememberedCount+=1} else {reviewCards.append(item)}
        answered+=1;revealed=false;strokeIndex=0;mistakeCount=0;solved=false
        return PracticeAnswer(item:item,remembered:remembered)
    }
    /// Legacy self-rating API retained for stored workflows. Keyboard exercises
    /// use submit/advance so an unverified answer cannot count as correct.
    @discardableResult public mutating func rate(remembered:Bool)->Shortcut? {
        guard revealed else{return nil}
        return finish(remembered:remembered)?.item
    }
}
