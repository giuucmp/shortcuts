import AppKit
import CoreGraphics
import ShortcutCore

enum HeldModifiers {
    /// Reads five modifier bits only. No events are posted and no typed keys are read.
    static var current:Modifiers {
        let flags=CGEventSource.flagsState(.combinedSessionState)
        var result:Modifiers=[]
        if flags.contains(.maskCommand) {result.insert(.command)}
        if flags.contains(.maskAlternate) {result.insert(.option)}
        if flags.contains(.maskControl) {result.insert(.control)}
        if flags.contains(.maskShift) {result.insert(.shift)}
        if flags.contains(.maskSecondaryFn) {result.insert(.function)}
        return result
    }
    static func fromEvent(_ flags:NSEvent.ModifierFlags)->Modifiers {
        var result:Modifiers=[]
        if flags.contains(.command) {result.insert(.command)}
        if flags.contains(.option) {result.insert(.option)}
        if flags.contains(.control) {result.insert(.control)}
        if flags.contains(.shift) {result.insert(.shift)}
        if flags.contains(.function) {result.insert(.function)}
        return result
    }
}
