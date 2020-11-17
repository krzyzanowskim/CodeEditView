import Foundation

public typealias TextAttribute = Dictionary<PartialKeyPath<String.AttributeKey>, Any>

/// Text attributes brain.
/// Text attributes stored as range -> attribute apply on re-layout to AttributedString
/// other than that text storage (String) and TextAttributes lives as a related data, that is no NSAttributedString
final class TextAttributes {
    private(set) var ranges: Dictionary<Range, TextAttribute>

    public init() {
        self.ranges = [:]
    }

    func add<Value>(_ attribute: KeyPath<String.AttributeKey, Value>, _ value: Value, _ range: Range) {
        // TODO: Once attribute is set (added) layout manager should update affected line with an updated attributed string.
        if var attributes = ranges[range] {
            attributes[attribute] = value
            ranges[range] = attributes
        } else {
            ranges[range] = [attribute: value]
        }
    }

    /// convert to char indices -> move -> convert back to Position is the only reasonable approach.
    /// Everything else is mindblown.
    func processRangeRemove(_ removeRange: Range, in textStorage: TextStorage, updateOperation: () -> Void) {
        _splitAttributedRanges(at: removeRange.start)

        let startIndex = textStorage.characterIndex(at: removeRange.start)
        let endIndex = textStorage.characterIndex(at: removeRange.end)
        let delta = abs(endIndex - startIndex)

        // Build character based ranges that are easier to move around
        // Not the fastest, but hey! quick and dirty, remember?
        let affectedRanges = ranges.reduce(into: [Swift.Range<Int>: TextAttribute]()) { (result, element) in
            let range = textStorage.characterIndex(at: element.key.start)..<textStorage.characterIndex(at: element.key.end)
            if range.startIndex > startIndex {
                result[range] = element.value
                ranges.removeValue(forKey: element.key)
            }
        }

        // Update storage
        updateOperation()

        let updatedRanges = affectedRanges.map { (range, attribute) in
            ((range.startIndex - delta)..<(range.endIndex - delta), attribute)
        }

        // rebuild ranges, BUT after storage modification!
        for (characterRange, attr) in updatedRanges {
            guard let newStart = textStorage.position(atCharacterIndex: characterRange.startIndex),
                  let newEnd = textStorage.position(atCharacterIndex: characterRange.endIndex)
            else {
                continue
            }
            let range = Range(start: newStart, end: newEnd)
            ranges[range] = attr
        }
    }

    /// Adjust attributed ranges after new string is added to the storage
    func processRangeInsert(_ string: String, at position: Position, in textStorage: TextStorage, updateOperation: () -> Void) {
        let startIndex = textStorage.characterIndex(at: position)
        let delta = string.count

        _splitAttributedRanges(at: position)

        let affectedRanges = ranges.reduce(into: [Swift.Range<Int>: TextAttribute]()) { (result, element) in
            let range = textStorage.characterIndex(at: element.key.start)..<textStorage.characterIndex(at: element.key.end)
            if range.startIndex >= startIndex {
                result[range] = element.value
                ranges.removeValue(forKey: element.key)
            }
        }

        // Update storage
        updateOperation()

        let updatedRanges = affectedRanges.map { (range, attribute) in
            ((range.startIndex + delta)..<(range.endIndex + delta), attribute)
        }

        // rebuild ranges, BUT after storage modification!
        for (characterRange, attr) in updatedRanges {
            guard let newStart = textStorage.position(atCharacterIndex: characterRange.startIndex),
                  let newEnd = textStorage.position(atCharacterIndex: characterRange.endIndex)
            else {
                continue
            }
            let range = Range(start: newStart, end: newEnd)
            ranges[range] = attr
        }
    }

    private func _splitAttributedRanges(at position: Position) {
        // Split ranges exactly at "position".
        // remember: Range.end is exclusive
        for (range, attributes) in ranges where range.contains(position) {
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
