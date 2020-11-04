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
        _adjustAttributedRanges(afterDidInsert: string, at: position)
        storageDidChange.send(Range(position))
    }

    public func remove(range: Range) {
        _storageProvider.remove(range: range)
        _adjustAttributedRanges(afterRemoveRange: range)
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

    private func _adjustAttributedRanges(afterRemoveRange removeRange: Range) {
        // Split at edges if needed
        // remove what's between edges
        let rangeLength = 1 // FIXME: This is is NOT correct lenght. It happen to fit now, but srsly. don't.

        for (range, attributes) in attributedRanges where range.intersects(removeRange) {
            let newRange = Range(
                start: range.start,
                end: range.end.position(before: rangeLength, in: self)!
            )
            
            if newRange != range { //, newRange.start != newRange.end {
                attributedRanges.removeValue(forKey: range)
                attributedRanges[newRange] = attributes
            }
        }

        // Everythign on the right move left by range length
        let position = removeRange.end
        for (range, attributes) in attributedRanges where range.start >= position && range.start.line == position.line {
            if let newStart = range.start.position(before: rangeLength, in: self),
               let newEnd = range.end.position(before: rangeLength, in: self)
            {
                attributedRanges.removeValue(forKey: range)
                attributedRanges[Range(start: newStart, end: newEnd)] = attributes
            }
        }
    }

    private func _splitAttributedRanges(at position: Position) {
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
                end: position
            )

            // and upper
            let upperRange = Range(
                start: position,
                end: range.end
            )

            attributedRanges[lowerRange] = attributes
            attributedRanges[upperRange] = attributes
        }
    }

    /// Adjust attributed ranges after new string is added to the storage
    private func _adjustAttributedRanges(afterDidInsert string: String, at position: Position) {
        _splitAttributedRanges(at: position)

        // Move everything following the newline position by one line
        if string.contains(where: \.isNewline) {
            let linesCount = string.count(isIncluded: \.isNewline)
            for (range, attributes) in attributedRanges where range.start > position {
                attributedRanges.removeValue(forKey: range)
                let newRange = Range(
                    start: Position(line: range.start.line + linesCount, character: range.start.character),
                    end: Position(line: range.end.line + linesCount, character: range.end.character)
                )
                attributedRanges[newRange] = attributes
            }
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
}
