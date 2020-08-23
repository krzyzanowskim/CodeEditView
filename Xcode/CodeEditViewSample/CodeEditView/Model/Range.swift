import Foundation

/// A range in a text document expressed as (zero-based) start and end positions
public struct Range {
    /// The range's start position.
    public let start: Position
    /// The range's end position.
    public let end: Position
}

//extension Range: Comparable {
//    public static func < (lhs: Range, rhs: Range) -> Bool {
//        if lhs.start < rhs.start {
//            return true
//        }
//
//    }
//}
