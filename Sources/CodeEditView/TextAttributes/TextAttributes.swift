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

    func adjustAttributedRanges(didRemoveRange removeRange: Range, in textStorage: TextStorage) {

        let startIndex = textStorage.characterIndex(at: removeRange.start)
        let endIndex = textStorage.characterIndex(at: removeRange.end)
        let removeRangeLength = abs(endIndex - startIndex)

        // same line
//        if removeRange.start.line == removeRange.end.line {
//
//            for (range, attributes) in ranges where range.overlaps(removeRange) {
//                let clamped = range.clamped(to: removeRange)
//                var lowerRange: Range?
//                var upperRange: Range?
//
//                // Split and ajust, results in two new ranges if needed.
//
//                if range.start != clamped.start {
//                    lowerRange = Range(range.start..<clamped.start)
//                }
//
//                if range.end != clamped.end {
//                    upperRange = Range(clamped.end..<range.end)
//                }
//
//                // It overlaps so either remove completly
//                // or replace with lower/upper ranges
//                ranges.removeValue(forKey: range)
//
//                if let rangeLower = lowerRange {
//                    ranges[rangeLower] = attributes
//                }
//
//                if let rangeUpper = upperRange {
//                    ranges[rangeUpper] = attributes
//                }
//            }
//
//            // Everything on the right move left by range length
//            for (range, attributes) in ranges where range.start >= removeRange.start && range.start.line == removeRange.start.line {
//                if let newStart = range.start.position(before: removeRangeLength, in: textStorage),
//                   let newEnd = range.end.position(before: removeRangeLength, in: textStorage)
//                {
//                    ranges.removeValue(forKey: range)
//                    ranges[Range(start: newStart, end: newEnd)] = attributes
//                }
//            }
//
//        }

        // Different lines. Backward delete, moves end line up to the end of start line
//        if removeRange.start.line != removeRange.end.line {
            // Delete back to previous line.
            // Remember this is "did remove".

            // split at newline?
            _splitAttributedRanges(at: removeRange.start)

            // O.M.G I hate it

            // Not work: select and delete across ranges

            /// just index, no position bs
            let changes = ranges
                .map { (range, attributes)  in
                    // Range -> Swift.Range<Int>
                    (old: range, range: textStorage.characterIndex(at: range.start)..<textStorage.characterIndex(at: range.end), attributes: attributes)
                }
                .filter {
                    // whatever is after
                    $0.1.startIndex > startIndex || $0.1.contains(startIndex)
                }
                .map { (oldRange, charsRange, attributes) -> (oldRange: Range, range: Swift.Range<Int>, attributes: TextAttribute) in
                    // move everything left by removeRangeLength
                    let newRange = charsRange.startIndex.advanced(by: -removeRangeLength)..<charsRange.endIndex.advanced(by: -removeRangeLength)
                    return (oldRange: oldRange, range: newRange, attributes: attributes)
                }.map { (oldRange, charsRange, attributes) -> (oldRange: Range, range: Range, attributes: TextAttribute) in
                    // rebuild Range
                    let range = Range(start: textStorage.position(atCharacterIndex: charsRange.startIndex)!, end: textStorage.position(atCharacterIndex: charsRange.endIndex)!)
                    return (oldRange, range, attributes)
                }

            // Apply changes
            for change in changes {
                ranges.removeValue(forKey: change.oldRange)
                ranges[change.range] = change.attributes
            }
        }
//    }

    /// Adjust attributed ranges after new string is added to the storage
    func adjustAttributedRanges(afterDidInsert string: String, at position: Position, in textStorage: TextStorage) {
        _splitAttributedRanges(at: position)

//        let positionIndex = textStorage.characterIndex(at: position)
//        let indexRanges = ranges.map { (range, attributes)  in
//            (range: textStorage.characterIndex(at: range.start)..<textStorage.characterIndex(at: range.end), attributes: attributes)
//        }
//
//        for (range, attributes) in indexRanges where range.contains(positionIndex) {
//            print("aqq")
//        }

        // Move everything following the newline position by one line,
        // and move ranges around
//        if string.contains(where: \.isNewline) {
//            let linesCount = string.count(isIncluded: \.isNewline)
//            for (range, attributes) in ranges where range.start >= position {
//                // move to the start of the next line
//                let newRange = Range(
//                    start: Position(line: range.start.line + linesCount, character: 0), // start at the next line
//                    end: Position(line: range.end.line + linesCount, character: range.end.character - range.start.character)
//                )
////                ranges.removeValue(forKey: range)
////                ranges[newRange] = attributes
//            }
//        }

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
