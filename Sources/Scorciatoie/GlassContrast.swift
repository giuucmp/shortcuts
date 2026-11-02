import AppKit
import CoreImage

/// Limits only the backdrop's extreme tones. Foreground text and the native
/// glass rim are outside this layer; no screen sampling or appearance guessing.
enum GlassContrast {
    // Core Animation evaluates Core Image filters in linear light. 0.04 is
    // about 56/255 in sRGB: dark backgrounds below it pass through unchanged.
    static let darkCeiling:CGFloat=0.04
    static let lightFloor:CGFloat=0.60

    static func filter(dark:Bool)->CIFilter? {
        guard let filter=CIFilter(name:"CIColorClamp") else{return nil}
        let lower:CGFloat=dark ? 0:lightFloor
        let upper:CGFloat=dark ? darkCeiling:1
        filter.setValue(CIVector(x:lower,y:lower,z:lower,w:0),forKey:"inputMinComponents")
        filter.setValue(CIVector(x:upper,y:upper,z:upper,w:1),forKey:"inputMaxComponents")
        return filter
    }
}

/// A transparent layer above Clear glass and below all shortcut content.
/// A background filter affects the backdrop, never its sibling text layer.
final class GlassContrastBackdrop:NSView {
    override init(frame:NSRect) {
        super.init(frame:frame)
        wantsLayer=true
        layer?.cornerRadius=17
        layer?.masksToBounds=true
        updateContrast()
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateContrast()
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContrast()
    }
    private func updateContrast() {
        // Clear glass can give descendants its own vibrant appearance. The
        // panel's appearance, not that internal material appearance, owns text.
        let dark=(window?.effectiveAppearance ?? effectiveAppearance).bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        // Replace the filter instead of mutating one already attached to a layer.
        backgroundFilters=GlassContrast.filter(dark:dark).map{[$0]} ?? []
    }
}

@available(macOS 26.0,*)
final class ShortcutGlassSurface:NSView {
    init(frame:NSRect,content:NSView) {
        super.init(frame:frame)
        // Background filters are ignored on a root layer. Give all siblings
        // one explicit backing layer even in an otherwise unbacked NSWindow.
        wantsLayer=true
        let glass=NSGlassEffectView(frame:bounds)
        glass.style = .clear;glass.cornerRadius=18
        glass.autoresizingMask=[.width,.height]
        let contrast=GlassContrastBackdrop(frame:bounds.insetBy(dx:1,dy:1))
        contrast.autoresizingMask=[.width,.height]
        // Glass isolates its content's backdrop. Siblings let the filter see
        // the glass while keeping text above it, with the original glass rim.
        addSubview(glass)
        addSubview(contrast)
        content.frame=bounds;content.autoresizingMask=[.width,.height]
        addSubview(content)
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
}

/// CGColor is not dynamic: resolve it again whenever the effective appearance changes.
final class OpaquePanelSurface:NSView {
    init(frame:NSRect,content:NSView) {
        super.init(frame:frame)
        wantsLayer=true;layer?.cornerRadius=18;layer?.masksToBounds=true
        content.frame=bounds;content.autoresizingMask=[.width,.height];addSubview(content)
        updateColor()
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
    override func viewDidChangeEffectiveAppearance() {super.viewDidChangeEffectiveAppearance();updateColor()}
    override func viewDidMoveToWindow() {super.viewDidMoveToWindow();updateColor()}
    private func updateColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {layer?.backgroundColor=NSColor.windowBackgroundColor.cgColor}
    }
}
