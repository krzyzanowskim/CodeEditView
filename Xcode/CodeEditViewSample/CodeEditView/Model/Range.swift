import Foundation

/// A range in a text document expressed as (zero-based) start and end positions.
/// The end position is exclusive. If you want to specify a range that contains
/// a line including the line ending character(s) then use an end position denoting
/// the start of the next line.
public struct Range: CustomDebugStringConvertible, CustomStringConvertible, Hashable, Equatable {
    /// The range's start position.
    public let start: Position
    /// The range's end position.
    public let end: Position

    public var debugDescription: String {
        "Range(start: \(start), end: \(end))"
    }

    public var description: String {
        "Range(start: \(start), end: \(end))"
    }

    func inverted() -> Self {
        return Range(start: end, end: start)
    }
}

//extension Range: Comparable {
//    public static func < (lhs: Range, rhs: Range) -> Bool {
//        if lhs.start < rhs.start {
//            return true
//        }
//
//    }
//}
