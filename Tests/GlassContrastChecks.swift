import AppKit
import QuartzCore
import Metal

/// Uses synthetic colors and never orders a window, samples the desktop,
/// installs an input monitor or starts the Scorciatoie app delegate.
@main struct GlassContrastChecks {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard #available(macOS 26.0,*) else {print("Glass checks require macOS 26+");return}
        guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {
            fputs("Metal unavailable: run this offscreen check outside the GPU sandbox.\n",stderr);exit(1)
        }
        var checks=0
        func check(_ condition:Bool,_ name:String) {
            guard condition else{fputs("FAIL: \(name)\n",stderr);exit(1)}
            checks+=1
        }
        let frame=NSRect(x:0,y:0,width:320,height:180)
        let root=NSView(frame:frame);root.wantsLayer=true
        let window=NSWindow(contentRect:frame,styleMask:[.borderless],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=root
        defer {window.close()}
        func foreground()->NSView {
            let content=NSView(frame:frame);content.wantsLayer=true
            let marker=CALayer();marker.frame=CGRect(x:100,y:50,width:30,height:30)
            marker.backgroundColor=NSColor.white.cgColor
            content.layer?.addSublayer(marker)
            return content
        }
        func surface(protected:Bool)->NSView {
            if protected {return ShortcutGlassSurface(frame:frame,content:foreground())}
            let view=NSView(frame:frame)
            let glass=NSGlassEffectView(frame:frame);glass.style = .clear;glass.cornerRadius=18
            view.addSubview(glass);view.addSubview(foreground())
            return view
        }
        func render(_ surface:NSView,dark:Bool,background:CGFloat)->[UInt8] {
            root.subviews.forEach{$0.removeFromSuperview()}
            root.layer?.backgroundColor=NSColor(srgbRed:background,green:background,blue:background,alpha:1).cgColor
            root.addSubview(surface)
            window.appearance=NSAppearance(named:dark ? .darkAqua:.aqua)
            root.layoutSubtreeIfNeeded();root.displayIfNeeded()
            RunLoop.main.run(until:Date(timeIntervalSinceNow:0.04))
            let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:320,height:180,mipmapped:false)
            descriptor.usage=[.renderTarget,.shaderRead,.shaderWrite];descriptor.storageMode = .shared
            let texture=device.makeTexture(descriptor:descriptor)!
            let renderer=CARenderer(mtlTexture:texture,options:[kCARendererMetalCommandQueue:queue,kCARendererColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])
            renderer.layer=root.layer;renderer.bounds=frame
            CATransaction.flush()
            renderer.beginFrame(atTime:CACurrentMediaTime(),timeStamp:nil);renderer.addUpdate(frame);renderer.render();renderer.endFrame()
            let completion=queue.makeCommandBuffer()!;completion.commit();completion.waitUntilCompleted()
            var pixels=[UInt8](repeating:0,count:320*180*4)
            texture.getBytes(&pixels,bytesPerRow:320*4,from:MTLRegionMake2D(0,0,320,180),mipmapLevel:0)
            return pixels
        }
        func pixel(_ image:[UInt8],_ x:Int=200,_ y:Int=90)->Int {Int(image[(y*320+x)*4])}
        let darkWhite=render(surface(protected:true),dark:true,background:1)
        let oldDarkWhite=render(surface(protected:false),dark:true,background:1)
        check(pixel(darkWhite)<=60 && pixel(oldDarkWhite)>150,"white backdrop is restrained in dark appearance")
        check(pixel(darkWhite,110,60)==255,"foreground remains white, outside the backdrop filter")
        check(pixel(darkWhite,160,0)==pixel(oldDarkWhite,160,0),"native glass rim is preserved")
        for background:CGFloat in [0,0.04,0.08,0.12] {
            let before=render(surface(protected:false),dark:true,background:background)
            let after=render(surface(protected:true),dark:true,background:background)
            check(abs(pixel(before)-pixel(after))<=1,"dark background \(background) keeps its native rendering")
        }
        let lightWhite=render(surface(protected:true),dark:false,background:1)
        let oldLightWhite=render(surface(protected:false),dark:false,background:1)
        check(abs(pixel(lightWhite)-pixel(oldLightWhite))<=1,"light theme on white remains unchanged")
        let lightDark=render(surface(protected:true),dark:false,background:0.08)
        check(pixel(lightDark)>=200,"light theme gets a readable backdrop over dark content")
        let changing=surface(protected:true)
        _=render(changing,dark:true,background:1)
        let switched=render(changing,dark:false,background:0.08)
        check(pixel(switched)>=200,"existing surface follows dark to light theme change")
        let switchedBack=render(changing,dark:true,background:1)
        check(pixel(switchedBack)<=60,"existing surface follows light to dark theme change")
        changing.setFrameSize(NSSize(width:640,height:360))
        check(changing.subviews[0].frame.size==changing.bounds.size && changing.subviews[1].frame.maxX==639 && changing.subviews[2].frame.size==changing.bounds.size,"all layers resize with the panel")
        check(!window.isVisible && !window.isKeyWindow,"test window never displayed or focused")
        let opaque=OpaquePanelSurface(frame:frame,content:foreground())
        let opaqueLight=render(opaque,dark:false,background:1)
        let opaqueDark=render(opaque,dark:true,background:1)
        check(pixel(opaqueLight)>200 && pixel(opaqueDark)<100,"opaque fallback changes its resolved background with appearance")
        check(pixel(render(opaque,dark:false,background:0))>200,"opaque fallback follows a second appearance change")
        for dark in [true,false] {
            for color in [NSColor.systemBlue,.systemPurple,.systemGreen,.systemOrange,.systemGray] {
                check(ShortcutAccent.contrast(ShortcutAccent.adjusted(color,dark:dark),ShortcutAccent.background(dark:dark))>=4.5,"accent retains contrast in both themes")
            }
        }
        // Functional secondary text must survive both the clamped backdrop and
        // the darker group fills. Dark appearance must keep the exact system RGBA.
        for name in [NSAppearance.Name.aqua,.accessibilityHighContrastAqua] {
            let appearance=NSAppearance(named:name)!
            appearance.performAsCurrentDrawingAppearance {
                let secondary=ShortcutSecondary.color.usingColorSpace(.sRGB)!
                check(secondary.alphaComponent==1,"light secondary is opaque")
                for component:CGFloat in [0.75,203.0/255,229.0/255,231.0/255,236.0/255] {
                    let background=NSColor(srgbRed:component,green:component,blue:component,alpha:1)
                    let ratio=ShortcutAccent.contrast(secondary,background)
                    check(ratio>=4.5,"light secondary contrast \(ratio) on \(component)")
                    if name == .aqua {print(String(format:"Secondary contrast on sRGB %.4f: %.3f:1",Double(component),ratio))}
                }
            }
        }
        for name in [NSAppearance.Name.darkAqua,.vibrantDark,.accessibilityHighContrastDarkAqua,.accessibilityHighContrastVibrantDark] {
            NSAppearance(named:name)!.performAsCurrentDrawingAppearance {
                let actual=ShortcutSecondary.color.usingColorSpace(.sRGB)!
                let original=NSColor.secondaryLabelColor.usingColorSpace(.sRGB)!
                check(actual.redComponent==original.redComponent && actual.greenComponent==original.greenComponent && actual.blueComponent==original.blueComponent && actual.alphaComponent==original.alphaComponent,"dark secondary exactly retains system RGBA for \(name.rawValue)")
            }
        }
        print("\(checks) native glass rendering checks passed")
    }
}
