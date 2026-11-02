import SwiftUI
import AppKit
import ShortcutCore

extension ShortcutTheme {
    var colorScheme:ColorScheme? {self == .system ? nil:self == .dark ? .dark:.light}
    var nativeAppearance:NSAppearance? {self == .system ? nil:NSAppearance(named:self == .dark ? .darkAqua:.aqua)}
}
