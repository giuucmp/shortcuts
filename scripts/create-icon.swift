import AppKit
let root=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels=size*scale
        let image=NSImage(size:NSSize(width:pixels,height:pixels))
        image.lockFocus()
        let rect=NSRect(x:Double(pixels)*0.055,y:Double(pixels)*0.055,width:Double(pixels)*0.89,height:Double(pixels)*0.89)
        let path=NSBezierPath(roundedRect:rect,xRadius:Double(pixels)*0.2,yRadius:Double(pixels)*0.2)
        NSGradient(starting:NSColor(srgbRed:0.22,green:0.48,blue:0.95,alpha:1),ending:NSColor(srgbRed:0.10,green:0.23,blue:0.58,alpha:1))!.draw(in:path,angle:90)
        let string="⌘" as NSString
        let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:Double(pixels)*0.64,weight:.medium),.foregroundColor:NSColor.white]
        let measured=string.size(withAttributes:attributes)
        string.draw(at:NSPoint(x:(Double(pixels)-measured.width)/2,y:(Double(pixels)-measured.height)/2+Double(pixels)*0.015),withAttributes:attributes)
        image.unlockFocus()
        let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
        let name="icon_\(size)x\(size)\(scale==2 ? "@2x":"").png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(name))
    }
}
