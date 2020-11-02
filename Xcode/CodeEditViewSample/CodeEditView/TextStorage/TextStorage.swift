import Foundation
import Combine
import Cocoa

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    /// String attributed and ranges. Range -> Attibute
    public var attributedRanges: Dictionary<Range, StringAttribute>
    public let storageDidChange = PassthroughSubject<Range, Never>()
    private let _storageProvider: TextStorageProvider

    public var linesCount: Int {
        _storageProvider.linesCount
    }

    public init(string: String = "") {
        _storageProvider = StringTextStorageProvider()
        attributedRanges = [:]
        if !string.isEmpty {
            insert(string: string, at: Position(line: 0, character: 0))
        }
    }

    public func insert(string: String, at position: Position) {
        //_adjustAttributedRanges(willInsert: string, at: position)
        _storageProvider.insert(string: string, at: position)
        _attributedRanges(afterDidInsert: string, at: position)
        storageDidChange.send(Range(position))
    }

    /// Adjust attributed ranges after new string is added to the storage
    private func _attributedRanges(afterDidInsert string: String, at position: Position) {

        // Split ranges exactly at "position".
        // remember: Range.end is exclusive
        for (range, attributes) in attributedRanges where range.intersects(Range(position)) {
            logger.debug("split attributed range \(range)")

            // remove current range
            attributedRanges.removeValue(forKey: range)

            // and replace with two new ranges

            // lower
            let lowerRange = Range(
                start: range.start,
                end: position.position(after: 1, in: self) ?? position
            )

            // and upper
            let upperRange = Range(
                start: position,
                end: Position(line: range.end.line, character: range.end.character)
            )

            attributedRanges[lowerRange] = attributes
            attributedRanges[upperRange] = attributes
        }

        // Move following ranges, at the same line, forward by string.count
        for (range, attributes) in attributedRanges where range.start >= position && range.start.line == position.line {
            if let newStart = range.start.position(after: string.count, in: self),
               let newEnd = range.end.position(after: string.count, in: self)
            {
                attributedRanges.removeValue(forKey: range)
                attributedRanges[Range(start: newStart, end: newEnd)] = attributes
            }
        }
    }

    public func remove(range: Range) {
        _storageProvider.remove(range: range)
        storageDidChange.send(range)
    }

    public func character(at position: Position) -> Character? {
        _storageProvider.character(at: position)
    }

    public func characterIndex(at position: Position) -> Int {
        _storageProvider.characterIndex(at: position)
    }

    public func position(atCharacterIndex characterIndex: Int) -> Position? {
        _storageProvider.position(atCharacterIndex: characterIndex)
    }

    public func string(in range: Range) -> Substring? {
        _storageProvider.string(in: range.start..<range.end)
    }

    public func string(in range: Swift.Range<Position>) -> Substring? {
        _storageProvider.string(in: range)
    }

    public func string(in range: Swift.ClosedRange<Position>) -> Substring? {
        _storageProvider.string(in: range)
    }

    public func string(line idx: Int) -> Substring {
        _storageProvider.string(line: idx)
    }

    public func add<Value>(_ attribute: KeyPath<String.AttributeKey, Value>, _ value: Value, _ range: Range) {
        // TODO: Once attribute is set (added) layout manager should update affected line
        //       with an updated attributed string.
        if var attributes = attributedRanges[range] {
            attributes[attribute] = value
            attributedRanges[range] = attributes
        } else {
            attributedRanges[range] = [attribute: value]
        }
    }

    // MARK: - Private

    /// Adjust attributes past insertion point.
    /// Split existing range at `position` if exists
//    private func _adjustAttributedRanges(willInsert string: String, at position: Position) {
////        if string.contains(where: \.isNewline) {
////            // there's new line, abort the ship! escape, there's no hope.
////
////            // Newline affects affected lines
////            // Position is at the end on the "previous" line, and
////            // we need to adjust attributes following, in the about-to-created new line
////            for (oldRange, attributes) in attributedRanges where oldRange.intersects(Range(position)) {
////                attributedRanges.removeValue(forKey: oldRange)
////                let newRange = Range(
////                    start: Position(line: oldRange.start.line + 1, character: oldRange.start.character),
////                    end: Position(line: oldRange.end.line + 1, character: oldRange.end.character)
////                )
////                attributedRanges[newRange] = attributes
////            }
////        }
//
//        for (range, attributes) in attributedRanges where range.intersects(Range(position)) {
//            logger.debug("split attributed range \(range)")
//
//            // remove current range
//            attributedRanges.removeValue(forKey: range)
//
//            // and replace with two new ranges
//
//            // lower
//            let lowerRange = Range(
//                start: range.start,
//                end: position
//            )
//
//            // and upper
//            let upperRange = Range(
//                start: position, //.position(after: string.count, in: self)!,
//                end: range.end.position(after: max(0, string.count - 1), in: self)!
//            )
//
//            attributedRanges[lowerRange] = attributes
//            attributedRanges[upperRange] = attributes
//        }
//
//        // now move following ranges by string.count
//        // but only in the same line as we grow the line.
//        // Unless this is a line break, then TODO
//        // (It would be way easier to deal with an offset instead Position
//
//        // !may need to slice range at position.character
//        for (range, attributes) in attributedRanges where range.start >= position && range.start.line == position.line {
//            if let newStart = range.start.moved(by: string.count, in: self),
//               let newEnd = range.end.moved(by: string.count, in: self)
//            {
//                attributedRanges.removeValue(forKey: range)
//                attributedRanges[Range(start: newStart, end: newEnd)] = attributes
//            }
//        }
//    }
}
