import Foundation
/// Pure state machine: observes only modifiers and the existence of a key press.
public struct ModifierSession {
    public private(set) var modifiers: Modifiers = []
    public private(set) var visible = false
    public private(set) var deadline: TimeInterval?
    public private(set) var suppressed = false
    public var delay: TimeInterval = 0.35
    public var shiftDelay: TimeInterval = 0.7
    public var triggers: Modifiers = .all
    public init() {}
    public mutating func update(_ flags: Modifiers, at time: TimeInterval) {
        modifiers = flags.intersection(.all)
        if modifiers.isEmpty { reset(); return }
        if !visible && modifiers.intersection(triggers).isEmpty {deadline=nil;return}
        guard !suppressed, !visible, deadline == nil, !modifiers.intersection(triggers).isEmpty else { return }
        deadline = time + (modifiers == .shift ? max(delay,shiftDelay) : delay)
    }
    public mutating func tick(at time: TimeInterval) {
        if let deadline, time >= deadline, !suppressed, !modifiers.isEmpty { visible = true; self.deadline = nil }
    }
    public mutating func pressKey() { visible = false; deadline = nil; suppressed = !modifiers.isEmpty }
    /// A read-only hardware/session check may remove released modifiers, but may
    /// never invent a press, arm an idle session, or reopen one after typing.
    public mutating func reconcileHeldModifiers(_ held:Modifiers,at time:TimeInterval) {
        guard !modifiers.isEmpty else{return}
        let remaining=modifiers.intersection(held)
        if remaining != modifiers {update(remaining,at:time)}
    }
    public func canPresent(physicallyHeld held:Modifiers)->Bool {
        visible && !suppressed && !modifiers.isEmpty && held.isSuperset(of:modifiers)
    }
    public mutating func reset() { modifiers=[]; visible=false; deadline=nil; suppressed=false }
}
