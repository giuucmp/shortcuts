import Foundation

/// A quick role probe may briefly precede first presentation, never indefinitely.
public struct FocusReadiness {
    private var generation=ScanGeneration()
    private var deadline:TimeInterval?
    public init() {}
    public mutating func begin(at time:TimeInterval)->Int {deadline=time+0.12;return generation.advance()}
    public mutating func cancel() {_ = generation.advance();deadline=nil}
    public mutating func finish(_ token:Int)->Bool {
        guard generation.accepts(token) else{return false}
        deadline=nil;return true
    }
    public func isWaiting(at time:TimeInterval)->Bool {deadline.map{time<$0} ?? false}
}
