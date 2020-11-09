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

    func adjustAttributedRanges(willRemoveRange removeRange: Range, in textStorage: TextStorage) {
//        var didUpdateRange = false

        // for-loop doesnt work here becase
        // iterates over `ranges` that also mutates
        // What we want is to iterated over mutated ranges (not the initial ranges)
//        self.ranges = ranges.reduce(into: [:]) { (r, kv) in
//            let range = kv.key
//            let attributes = kv.value
//            r[range] = attributes
//
//            guard range.overlaps(removeRange) else {
//                return
//            }
//
//            let clamped = range.clamped(to: removeRange)
//            var lowerRange: Range?
//            var upperRange: Range?
//
//            // Split and ajust, results in two new ranges if needed.
//
//            if range.start != clamped.start {
//                lowerRange = Range(range.start..<clamped.start)
//            }
//
//            if range.end != clamped.end {
//                upperRange = Range(clamped.end..<range.end)
//            }
//
//            if lowerRange != nil || upperRange != nil {
//                // skip this range, aka remove
//                // ranges.removeValue(forKey: range)
//                r[range] = nil
//
//                if let rangeLower = lowerRange {
//                    r[rangeLower] = attributes
//                }
//
//                if let rangeUpper = upperRange {
//                    r[rangeUpper] = attributes
//                }
//            }
//        }

        for (range, attributes) in ranges where range.overlaps(removeRange) {
            let clamped = range.clamped(to: removeRange)
            var lowerRange: Range?
            var upperRange: Range?

            // Split and ajust, results in two new ranges if needed.

            if range.start != clamped.start {
                lowerRange = Range(range.start..<clamped.start)
            }

            if range.end != clamped.end {
                upperRange = Range(clamped.end..<range.end)
            }

            // It overlaps so either remove completly
            // or replace with lower/upper ranges
            ranges.removeValue(forKey: range)

            if let rangeLower = lowerRange {
                ranges[rangeLower] = attributes
            }

            if let rangeUpper = upperRange {
                ranges[rangeUpper] = attributes
            }
        }

        // Everything on the right move left by range length
        let startIndex = textStorage.characterIndex(at: removeRange.start)
        let endIndex = textStorage.characterIndex(at: removeRange.end)
        let removeRangeLength = abs(endIndex - startIndex)

        let position = removeRange.start
        for (range, attributes) in ranges where range.start >= position && range.start.line == position.line {
            if let newStart = range.start.position(before: removeRangeLength, in: textStorage),
               let newEnd = range.end.position(before: removeRangeLength, in: textStorage)
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
        for (range, attributes) in ranges where range.overlaps(Range(position)) {
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
