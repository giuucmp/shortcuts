import AppKit

enum ShortcutAccent {
    // Conservative bounds including the subtle group fill above protected glass.
    static func background(dark:Bool)->NSColor {
        let component:CGFloat=dark ? 0.27:0.75
        return NSColor(srgbRed:component,green:component,blue:component,alpha:1)
    }
    static func contrast(_ a:NSColor,_ b:NSColor)->Double {
        func luminance(_ value:NSColor)->Double {
            let rgb=value.usingColorSpace(.sRGB) ?? .black
            func linear(_ channel:CGFloat)->Double {
                let c=Double(channel);return c<=0.04045 ? c/12.92:pow((c+0.055)/1.055,2.4)
            }
            return 0.2126*linear(rgb.redComponent)+0.7152*linear(rgb.greenComponent)+0.0722*linear(rgb.blueComponent)
        }
        let first=luminance(a),second=luminance(b)
        return (max(first,second)+0.05)/(min(first,second)+0.05)
    }
    static func adjusted(_ accent:NSColor,dark:Bool)->NSColor {
        let rgb=accent.usingColorSpace(.sRGB) ?? .systemBlue
        let destination:CGFloat=dark ? 1:0
        for step in 0...20 {
            let amount=CGFloat(step)/20
            let color=NSColor(srgbRed:rgb.redComponent*(1-amount)+destination*amount,green:rgb.greenComponent*(1-amount)+destination*amount,blue:rgb.blueComponent*(1-amount)+destination*amount,alpha:1)
            if contrast(color,background(dark:dark))>=4.5 {return color}
        }
        return dark ? .white:.black
    }
    static func color(dark:Bool)->NSColor {
        var accent=NSColor.systemBlue
        NSAppearance(named:dark ? .darkAqua:.aqua)?.performAsCurrentDrawingAppearance {
            accent=NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        }
        return adjusted(accent,dark:dark)
    }
}

/// Opaque light secondary text clears 4.5:1 even on protected glass plus group
/// fills. Dark appearances keep the unmodified native secondary label color.
enum ShortcutSecondary {
    static let color=NSColor(name:NSColor.Name("ScorciatoieSecondary")) {appearance in
        if appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua {return .secondaryLabelColor}
        return NSColor(srgbRed:0.30,green:0.30,blue:0.30,alpha:1)
    }
}
