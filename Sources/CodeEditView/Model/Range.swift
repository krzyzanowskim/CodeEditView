import Foundation

/// A range in a text document expressed as (zero-based) start and end positions.
/// The end position is exclusive. If you want to specify a range that contains
/// a line including the line ending character(s) then use an end position denoting
/// the start of the next line.
public struct Range: CustomDebugStringConvertible, CustomStringConvertible, Hashable, Equatable {
    /// The range's start position.
    public let start: Position
    /// The range's end position.
    /// The end position is exclusive.
    public let end: Position

    static let zero = Range(start: .zero, end: Position(line: 0, character: 1))

    init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }

    init(_ range: Swift.Range<Position>) {
        self.start = range.lowerBound
        self.end = range.upperBound
    }

    @available(*, deprecated, message: "deprecated")
    init(_ position: Position) {
        self.start = position
        self.end = Position(line: position.line, character: position.character + 1)
    }

    public var debugDescription: String {
        "Range(start: \(start), end: \(end))"
    }

    public var description: String {
        "Range(start: \(start), end: \(end))"
    }

    func inverted() -> Self {
        return Range(start: end, end: start)
    }

    func clamped(to otherRange: Range) -> Range {
        Range((start..<end).clamped(to: (otherRange.start..<otherRange.end)))
    }

    func overlaps(_ otherRange: Range) -> Bool {
        (start..<end).overlaps(otherRange.start..<otherRange.end)
    }
}

extension Range: Comparable {
    public static func < (lhs: Range, rhs: Range) -> Bool {
        lhs.start < rhs.start
    }
}
