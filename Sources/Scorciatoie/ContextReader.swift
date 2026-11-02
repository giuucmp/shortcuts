import AppKit
import ApplicationServices
import ShortcutCore

enum ContextReader {
    struct Result {var context:ActiveContext;var role:String?}
    /// A bounded structural probe, independent of the slower menu scan.
    static func read(pid:pid_t,bundle:String)->Result {
        let deadline=ProcessInfo.processInfo.systemUptime+0.10
        let app=AXUIElementCreateApplication(pid)
        func value(_ node:AXUIElement,_ attribute:String)->CFTypeRef? {
            guard ProcessInfo.processInfo.systemUptime<deadline else{return nil}
            AXUIElementSetMessagingTimeout(node,0.012)
            return AccessibilityReader.value(node,attribute)
        }
        guard let focus=AccessibilityReader.element(value(app,kAXFocusedUIElementAttribute)) else{return Result(context:ActiveContext(),role:nil)}
        var window:AXUIElement?,path=[FocusMetadata](),current:AXUIElement?=focus,visited=[AXUIElement]()
        var selected:Bool?
        // One IPC per ancestor instead of several serial calls. None of these
        // attributes contains the text value, selection text, URL or window title.
        let attributes=[kAXRoleAttribute,kAXIdentifierAttribute,kAXDescriptionAttribute,kAXParentAttribute,kAXSelectedTextRangeAttribute,kAXWindowAttribute] as CFArray
        for _ in 0..<10 {
            guard let node=current,ProcessInfo.processInfo.systemUptime<deadline,!visited.contains(where:{CFEqual($0,node)}) else{break}
            visited.append(node);AXUIElementSetMessagingTimeout(node,0.012)
            var raw:CFArray?
            guard AXUIElementCopyMultipleAttributeValues(node,attributes,AXCopyMultipleAttributeOptions(rawValue:0),&raw) == .success,let values=raw as? [Any],values.count==6 else{break}
            let role=values[0] as? String ?? ""
            if window == nil {window=AccessibilityReader.element(values[5] as CFTypeRef)}
            if role == kAXWindowRole {window=node;break}
            if role == kAXApplicationRole {break}
            path.append(FocusMetadata(role:role,identifier:values[1] as? String ?? "",description:values[2] as? String ?? ""))
            if visited.count==1,CFGetTypeID(values[4] as CFTypeRef)==AXValueGetTypeID() {
                let ax=unsafeBitCast(values[4] as CFTypeRef,to:AXValue.self)
                if AXValueGetType(ax) == .cfRange {var range=CFRange();if AXValueGetValue(ax,.cfRange,&range){selected=range.length>0}}
            }
            current=AccessibilityReader.element(values[3] as CFTypeRef)
        }
        var hasWindow:Bool? = window == nil ? nil:true
        if window == nil,ProcessInfo.processInfo.systemUptime<deadline {
            var raw:CFTypeRef?
            let status=AXUIElementCopyAttributeValue(app,kAXFocusedWindowAttribute as CFString,&raw)
            window=AccessibilityReader.element(raw)
            hasWindow=window != nil ? true:status == .noValue || status == .success ? false:nil
        }
        var context=ActiveContext(area:FocusClassifier.area(bundle:bundle,path:path),hasWindow:hasWindow,hasTextSelection:selected)
        // A selected navigation tab is evidence; a button merely labelled Code isn't.
        if bundle == "com.anthropic.claudefordesktop",let window {
            var pending=[(window,0)],count=0
            while !pending.isEmpty,count<100,ProcessInfo.processInfo.systemUptime<deadline {
                let (node,depth)=pending.removeFirst();count+=1
                let role=value(node,kAXRoleAttribute) as? String ?? ""
                if [kAXRadioButtonRole,"AXTab"].contains(role) {
                    let title=(value(node,kAXTitleAttribute) as? String) ?? (value(node,kAXDescriptionAttribute) as? String) ?? ""
                    if ["Code","Chat","Cowork"].contains(title) {
                        let selected=(value(node,kAXSelectedAttribute) as? NSNumber)?.boolValue ?? (value(node,kAXValueAttribute) as? NSNumber)?.boolValue
                        if selected == true {context.claudeSection=title;break}
                    }
                }
                // Do not traverse text content, tables or session/document lists.
                if depth<7,[kAXWindowRole,kAXGroupRole,kAXSplitGroupRole,kAXScrollAreaRole,kAXTabGroupRole,"AXWebArea","AXToolbar"].contains(role),let children=value(node,kAXChildrenAttribute) as? [AXUIElement] {
                    pending.append(contentsOf:children.prefix(30).map{($0,depth+1)})
                }
            }
        }
        // Reserve one final call even when optional traversal hit its deadline.
        AXUIElementSetMessagingTimeout(app,0.008)
        guard let end=AccessibilityReader.element(AccessibilityReader.value(app,kAXFocusedUIElementAttribute)),CFEqual(focus,end) else{return Result(context:ActiveContext(),role:nil)}
        return Result(context:context,role:path.first?.role)
    }
}
