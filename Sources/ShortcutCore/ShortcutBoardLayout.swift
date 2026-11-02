import Foundation

/// Natural-height functional groups, balanced across columns. No scrolling,
/// paging or arbitrary cutoff; the enclosing panel hugs the occupied content.
public enum ShortcutBoardLayout {
    public struct Group:Identifiable {
        public let id:String
        public let category:String
        public let shortcuts:[Shortcut]
        public let part:Int
        public let partCount:Int
        public let height:Double
        fileprivate let ordinal:Int
    }
    public struct Column {
        public let groups:[Group]
        public let height:Double
    }
    public struct Fit {
        public let columns:[Column]
        public let scale:Double
        public let columnWidth:Double
        public let gap:Double
        public let height:Double
        public let secondary:Bool
        public let showContext:Bool
    }
    public struct Board {
        public let width:Double
        public let height:Double
        public let application:Fit?
        public let system:Fit?
        public var contentHeight:Double {height-chromeHeight}
    }
    public static let chromeHeight=70.0
    public static func detail(_ item:Shortcut)->String? {
        let context=ShortcutPresentation.context(item)
        switch context.kind {
        case .general,.availableNow:return nil
        default:return context.summary
        }
    }
    public static func rowHeight(_ item:Shortcut,secondary:Bool)->Double {
        detail(item)==nil ? (secondary ? 16:18):(secondary ? 23:27)
    }
    public static func headerHeight(secondary:Bool)->Double {secondary ? 19:24}
    public static func fit(_ items:[Shortcut],width:Double,maximumHeight:Double,secondary:Bool=false,favorites:Set<String>=[],textScale:Double=1,showContext:Bool=true)->Fit {
        let availableWidth=max(1,width),limit=max(1,maximumHeight),gap=8.0
        guard !items.isEmpty else{return Fit(columns:[],scale:1,columnWidth:availableWidth,gap:gap,height:0,secondary:secondary,showContext:showContext)}
        let ordered=ShortcutImportance.ordered(items,favorites:favorites)
        let grouped=Dictionary(grouping:ordered,by:ShortcutPresentation.group)
        let names=ShortcutPresentation.groupOrder.filter{grouped[$0] != nil}+grouped.keys.filter{!ShortcutPresentation.groupOrder.contains($0)}.sorted()
        let heightsByItem=Dictionary(items.map{($0,showContext ? rowHeight($0,secondary:secondary):(secondary ? 16:18))},uniquingKeysWith:{first,_ in first})
        let header=headerHeight(secondary:secondary)+12
        let total=names.reduce(0.0){$0+header+grouped[$1]!.reduce(0){$0+heightsByItem[$1]!}}
        let maxColumns=min(12,max(1,Int(availableWidth/((secondary ? 170:200)*textScale))))
        var best:Fit?
        for count in 1...maxColumns {
            let columnWidth=max(1,(availableWidth-Double(count-1)*gap)/Double(count))
            let target=max(header+50,total/Double(count)*1.12)
            var blocks=[Group](),ordinal=0
            for name in names {
                let groupHeight=header+grouped[name]!.reduce(0){$0+heightsByItem[$1]!}
                let readableCapacity=limit/min(textScale,columnWidth/(secondary ? 210:250))
                // Keep a functional group intact unless it really exceeds a column.
                let chunkLimit=groupHeight<=readableCapacity*1.15 ? Double.infinity:target
                var chunk=[Shortcut](),height=header,chunks=[([Shortcut],Double)]()
                func appendChunk() {
                    guard !chunk.isEmpty else{return}
                    chunks.append((chunk,height));chunk=[];height=header
                }
                for item in grouped[name]! {
                    let h=heightsByItem[item]!
                    if height+h>chunkLimit && !chunk.isEmpty {appendChunk()}
                    chunk.append(item);height+=h
                }
                appendChunk()
                for (part,chunk) in chunks.enumerated() {
                    blocks.append(Group(id:name+":"+chunk.0[0].id,category:name,shortcuts:chunk.0,part:part,partCount:chunks.count,height:chunk.1,ordinal:ordinal))
                    ordinal+=1
                }
            }
            // Contiguous columns preserve the reading order through modifier filters.
            func pack(_ capacity:Double)->[[Group]] {
                var columns=[[Group]](),column=[Group](),height=0.0
                for block in blocks {
                    let next=height+(column.isEmpty ? 0:gap)+block.height
                    if next>capacity && !column.isEmpty {columns.append(column);column=[];height=0}
                    if !column.isEmpty {height+=gap}
                    column.append(block);height+=block.height
                }
                if !column.isEmpty {columns.append(column)}
                return columns
            }
            var low=blocks.map(\.height).max() ?? 0
            var high=blocks.reduce(0){$0+$1.height}+Double(max(0,blocks.count-1))*gap
            for _ in 0..<24 {
                let middle=(low+high)/2
                if pack(middle).count>count {low=middle} else {high=middle}
            }
            let columns=pack(high+0.001)
            let heights=columns.map{$0.reduce(0){$0+$1.height}+Double(max(0,$0.count-1))*gap}
            let actualWidth=max(1,(availableWidth-Double(columns.count-1)*gap)/Double(columns.count))
            let occupied=heights.max() ?? 1
            let scale=min(textScale,actualWidth/(secondary ? 210:250),limit/occupied)
            let result=Fit(columns:columns.indices.map{i in
                Column(groups:columns[i],height:heights[i]*scale)
            },scale:scale,columnWidth:actualWidth,gap:gap,height:occupied*scale,secondary:secondary,showContext:showContext)
            if best==nil || result.scale>(best?.scale ?? 0)+0.001 || (abs(result.scale-(best?.scale ?? 0))<0.001 && result.height<(best?.height ?? .infinity)) {best=result}
        }
        return best!
    }
    public static func board(_ items:[Shortcut],width:Double,maximumContentHeight:Double,favorites:Set<String>=[],textScale:Double=1,showContext:Bool=true)->Board {
        let contentWidth=max(1,width-24),height=max(1,maximumContentHeight)
        guard !items.isEmpty else{return Board(width:width,height:chromeHeight+min(28,height),application:nil,system:nil)}
        let appItems=items.filter{!$0.isSystem},systemItems=items.filter(\.isSystem)
        var system=systemItems.isEmpty ? nil:fit(systemItems,width:contentWidth,maximumHeight:appItems.isEmpty ? height-16:min(110,height*0.22),secondary:true,favorites:favorites,textScale:textScale,showContext:showContext)
        var systemHeight=system.map{$0.height+16} ?? 0
        let spacing=appItems.isEmpty || systemItems.isEmpty ? 0.0:10.0
        let application=appItems.isEmpty ? nil:fit(appItems,width:contentWidth,maximumHeight:max(1,height-systemHeight-spacing),favorites:favorites,textScale:textScale,showContext:showContext)
        // Spend only genuinely unused height on macOS. Never shrink the app
        // to make the secondary section larger, and retain every system entry.
        if let application,let current=system {
            let budget=min(height*0.35,height-application.height-spacing-16)
            if budget>current.height+1 {
                let expanded=fit(systemItems,width:contentWidth,maximumHeight:budget,secondary:true,favorites:favorites,textScale:textScale*0.9,showContext:showContext)
                if expanded.scale>current.scale {system=expanded;systemHeight=expanded.height+16}
            }
        }
        return Board(width:width,height:chromeHeight+(application?.height ?? 0)+spacing+systemHeight,application:application,system:system)
    }
    public static func preferred(_ items:[Shortcut],maximumWidth:Double,maximumHeight:Double,favorites:Set<String>=[],textScale:Double=1,showContext:Bool=true)->Board {
        let maxWidth=max(1,maximumWidth),maxHeight=max(chromeHeight+1,maximumHeight)
        let widths=Array(Set([400.0,560,720,900,1100,1320,1560,1800].filter{$0<maxWidth}+[maxWidth])).sorted()
        let boards=widths.map{board(items,width:$0,maximumContentHeight:maxHeight-chromeHeight,favorites:favorites,textScale:textScale,showContext:showContext)}
        func scale(_ b:Board)->Double {b.application?.scale ?? b.system?.scale ?? 1}
        let readable=boards.filter{scale($0)>=textScale*0.94}
        let balanced=readable.filter{($0.system?.scale ?? textScale)>=textScale*0.8}
        if let compact=(balanced.isEmpty ? readable:balanced).min(by:{$0.width*$0.height < $1.width*$1.height}) {return compact}
        return boards.max {a,b in
            if abs(scale(a)-scale(b))>0.001 {return scale(a)<scale(b)}
            if abs((a.system?.scale ?? 1)-(b.system?.scale ?? 1))>0.001 {return (a.system?.scale ?? 1)<(b.system?.scale ?? 1)}
            return a.width*a.height>b.width*b.height
        }!
    }
}
