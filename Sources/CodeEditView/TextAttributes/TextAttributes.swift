import Foundation

public typealias TextAttribute = Dictionary<PartialKeyPath<String.AttributeKey>, Any>

final class TextAttributes {
    private(set) var ranges: Dictionary<Range, TextAttribute>

    public init() {
        self.ranges = [:]
    }

    func add<Value>(_ attribute: KeyPath<String.AttributeKey, Value>, _ value: Value, _ range: Range) {
        // TODO: Once attribute is set (added) layout manager should update affected line
        //       with an updated attributed string.
        if var attributes = ranges[range] {
            attributes[attribute] = value
            ranges[range] = attributes
        } else {
            ranges[range] = [attribute: value]
        }
    }

    func adjustAttributedRanges(afterRemoveRange removeRange: Range, in textStorage: TextStorage) {
        // Split at edges if needed
        // remove what's between edges
        let rangeLength = 1 // FIXME: This is is NOT correct lenght. It happen to fit now, but srsly. don't.

        for (range, attributes) in ranges where range.intersects(removeRange) {
            let newRange = Range(
                start: range.start,
                end: range.end.position(before: rangeLength, in: textStorage)!
            )

            if newRange != range { //, newRange.start != newRange.end {
                ranges.removeValue(forKey: range)
                ranges[newRange] = attributes
            }
        }

        // Everythign on the right move left by range length
        let position = removeRange.end
        for (range, attributes) in ranges where range.start >= position && range.start.line == position.line {
            if let newStart = range.start.position(before: rangeLength, in: textStorage),
               let newEnd = range.end.position(before: rangeLength, in: textStorage)
            {
                ranges.removeValue(forKey: range)
                ranges[Range(start: newStart, end: newEnd)] = attributes
            }
        }
    }

    /// Adjust attributed ranges after new string is added to the storage
    func adjustAttributedRanges(afterDidInsert string: String, at position: Position, in textStorage: TextStorage) {
        _splitAttributedRanges(at: position)

        // Move everything following the newline position by one line
        if string.contains(where: \.isNewline) {
            let linesCount = string.count(isIncluded: \.isNewline)
            for (range, attributes) in ranges where range.start > position {
                ranges.removeValue(forKey: range)
                let newRange = Range(
                    start: Position(line: range.start.line + linesCount, character: range.start.character),
                    end: Position(line: range.end.line + linesCount, character: range.end.character)
                )
                ranges[newRange] = attributes
            }
        }

        // Move following ranges, at the same line, forward by string.count
        for (range, attributes) in ranges where range.start >= position && range.start.line == position.line {
            if let newStart = range.start.position(after: string.count, in: textStorage),
               let newEnd = range.end.position(after: string.count, in: textStorage)
            {
                ranges.removeValue(forKey: range)
                ranges[Range(start: newStart, end: newEnd)] = attributes
            }
        }
    }

    private func _splitAttributedRanges(at position: Position) {
        // Split ranges exactly at "position".
        // remember: Range.end is exclusive
        for (range, attributes) in ranges where range.intersects(Range(position)) {
            logger.debug("split attributed range \(range)")

            // remove current range
            ranges.removeValue(forKey: range)

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

            ranges[lowerRange] = attributes
            ranges[upperRange] = attributes
        }
    }
}
