import Foundation
import ShortcutCore

func checkPracticeKeyboard() {
    // A drill must never ask the user to execute a shortcut intercepted by macOS.
    let reserved:[KeyStroke] = [
        .init(key:"Tab",modifiers:.command), .init(key:"Tab",modifiers:[.command,.shift]),
        .init(key:"Space",modifiers:.command), .init(key:"Space",modifiers:.control),
        .init(key:"Q",modifiers:[.command,.control]), .init(key:"Q",modifiers:[.command,.shift]),
        .init(key:"Escape",modifiers:[.command,.option]), .init(key:"D",modifiers:[.command,.option]),
        .init(key:"3",modifiers:[.command,.shift]), .init(key:"4",modifiers:[.command,.shift,.control]),
        .init(key:"5",modifiers:[.command,.shift]), .init(key:"Up",modifiers:.control),
        .init(key:"Left",modifiers:.control), .init(key:"1",modifiers:.control), .init(key:"F11"), .init(key:"Q",modifiers:.function)
    ]
    let blocked=reserved.enumerated().map {index,stroke in
        Shortcut(id:"blocked-\(index)",profile:"editor",title:"Action \(index)",category:"File",strokes:[stroke],source:.personal)
    }
    XCTAssertTrue(PracticeSession(items:blocked,limit:100,includeSystem:true).cards.isEmpty,"Reserved combinations must be excluded even when declared by an app or personal binding")
    let safe=Shortcut(id:"quit",profile:"editor",title:"Quit",category:"File",strokes:[.init(key:"Q",modifiers:.command)],source:.catalog)
    XCTAssertEqual(PracticeSession(items:[safe]).cards.map(\.id),["quit"])

    // Exact modifiers matter; punctuation may require Shift on the active layout.
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"c",modifiers:.command),expected:.init(key:"C",modifiers:.command)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"C",modifiers:[.command,.shift]),expected:.init(key:"C",modifiers:.command)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"C",modifiers:[.command,.option]),expected:.init(key:"C",modifiers:.command)))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"=",characters:"+",modifiers:[.command,.shift]),expected:.init(key:"+",modifiers:.command)))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"+",characters:"+",modifiers:.command),expected:.init(key:"+",modifiers:.command)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"=",characters:"=",modifiers:.command),expected:.init(key:"+",modifiers:.command)))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:".",characters:">",modifiers:[.command,.shift]),expected:.init(key:".",modifiers:[.command,.shift])))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:".",characters:".",modifiers:.command),expected:.init(key:".",modifiers:[.command,.shift])))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"5",characters:"[",modifiers:[.command,.option]),expected:.init(key:"[",modifiers:.command)))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"5",characters:"{",modifiers:[.command,.option,.shift]),expected:.init(key:"{",modifiers:.command)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:".",characters:".",modifiers:[.command,.option]),expected:.init(key:".",modifiers:.command)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"X",modifiers:.command),expected:.init(key:"C",modifiers:.command)))
    XCTAssertTrue(PracticeKeyboard.matches(.init(key:"Return"),expected:.init(key:"⏎")))
    // Portable and full-size keyboards report different events for the same Fn action.
    for (portable,native) in [("Return","Enter"),("Delete","ForwardDelete"),("Left","Home"),("Right","End"),("Up","PageUp"),("Down","PageDown")] {
        XCTAssertTrue(PracticeKeyboard.matches(.init(key:native,modifiers:.command),expected:.init(key:portable,modifiers:[.command,.function])))
        XCTAssertTrue(PracticeKeyboard.matches(.init(key:native,modifiers:[.command,.function]),expected:.init(key:portable,modifiers:[.command,.function])))
        XCTAssertTrue(PracticeKeyboard.matches(.init(key:portable,modifiers:[.command,.function]),expected:.init(key:native,modifiers:.command)))
    }
    let portableEnter=Shortcut(id:"enter",profile:"editor",title:"Enter",category:"Edit",strokes:[.init(key:"Return",modifiers:.function)],source:.personal)
    XCTAssertEqual(PracticeSession(items:[portableEnter]).cards.count,1)
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"Return"),expected:.init(key:"Return",modifiers:.function)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"Delete"),expected:.init(key:"Delete",modifiers:.function)))
    XCTAssertFalse(PracticeKeyboard.matches(.init(key:"Home",modifiers:.control),expected:.init(key:"Left",modifiers:[.command,.function])))

    // Only a full, correct, unassisted answer counts as first-attempt recall.
    let copy=Shortcut(id:"copy",profile:"editor",title:"Copy",category:"Edit",strokes:[.init(key:"C",modifiers:.command)],source:.catalog)
    var drill=PracticeSession(items:[copy])
    XCTAssertTrue(drill.advance()==nil)
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command,isRepeat:true)),.ignored)
    XCTAssertFalse(drill.solved)
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command)),.correct)
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command)),.ignored)
    XCTAssertEqual(drill.advance()?.remembered,true)
    XCTAssertEqual(drill.rememberedCount,1)
    XCTAssertTrue(drill.completed)
    XCTAssertTrue(drill.advance()==nil)
    drill=PracticeSession(items:[copy])
    XCTAssertEqual(drill.submit(.init(key:"X",modifiers:.command)),.incorrect)
    XCTAssertEqual(drill.mistakeCount,1)
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command)),.correct)
    XCTAssertEqual(drill.advance()?.remembered,false)
    XCTAssertEqual(drill.rememberedCount,0)
    XCTAssertEqual(drill.reviewCards.map(\.id),["copy"])
    drill=PracticeSession(items:[copy]);drill.reveal()
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command)),.correct)
    XCTAssertEqual(drill.advance()?.remembered,false)
    drill=PracticeSession(items:[copy])
    XCTAssertEqual(drill.skip()?.item.id,"copy")
    XCTAssertEqual(drill.reviewCards.map(\.id),["copy"])
    XCTAssertTrue(drill.skip()==nil)
    // Sequences require ordered chords; a wrong chord or focus loss resets progress.
    let sequence=Shortcut(id:"sequence",profile:"editor",title:"Comment",category:"Edit",strokes:[.init(key:"K",modifiers:.command),.init(key:"C",modifiers:.command)],source:.catalog)
    drill=PracticeSession(items:[sequence])
    XCTAssertEqual(drill.submit(.init(key:"K",modifiers:.command)),.stepMatched(completed:1,total:2))
    XCTAssertEqual(drill.submit(.init(key:"K",modifiers:.command,isRepeat:true)),.ignored)
    XCTAssertEqual(drill.strokeIndex,1)
    XCTAssertEqual(drill.submit(.init(key:"X",modifiers:.command)),.incorrect)
    XCTAssertEqual(drill.strokeIndex,0)
    XCTAssertEqual(drill.submit(.init(key:"K",modifiers:.command)),.stepMatched(completed:1,total:2))
    drill.resetSequence()
    XCTAssertEqual(drill.strokeIndex,0)
    XCTAssertEqual(drill.mistakeCount,1)
    XCTAssertEqual(drill.submit(.init(key:"K",modifiers:.command)),.stepMatched(completed:1,total:2))
    XCTAssertEqual(drill.submit(.init(key:"C",modifiers:.command)),.correct)
    XCTAssertEqual(drill.advance()?.remembered,false)
    let exclusions=PracticeSession(items:blocked+[safe],limit:1,includeSystem:true)
    XCTAssertEqual(exclusions.excludedReservedCount,blocked.count)
    XCTAssertEqual(exclusions.cards.count,1)
    var mixed=sequence;mixed.strokes.append(.init(key:"Tab",modifiers:.command))
    XCTAssertTrue(PracticeSession(items:[mixed],includeSystem:true).cards.isEmpty)
}
