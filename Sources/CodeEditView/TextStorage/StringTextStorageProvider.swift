import Foundation

/// Dummy String based storage provider
class StringTextStorageProvider: TextStorageProvider {
    private var _content: String = ""

    /// Cache lines and ranges including newline character at the end.
    private var _cacheLineRange: [Int: Swift.Range<String.Index>] = [:]

    var linesCount: Int {
        _cacheLineRange.count
    }

    func insert(string: String, at position: Position) {
        let index = _content.index(offset(line: position.line), offsetBy: position.character)
        _content.insert(contentsOf: string, at: index)
        if string.contains(where: \.isNewline) {
            logger.debug("newLine!")
        }
        invalidateLinesCache()
    }

    func remove(range: Range) {
        guard !_content.isEmpty else {
            return
        }

        let startIndex = _content.index(offset(line: range.start.line), offsetBy: range.start.character)
        let endIndex = _content.index(offset(line: range.end.line), offsetBy: range.end.character)
        _content.removeSubrange(startIndex..<endIndex)
        invalidateLinesCache()
    }

    func string(in range: Swift.Range<Position>) -> Substring? {
        let startOffset = _content.index(offset(line: range.lowerBound.line), offsetBy: range.lowerBound.character)
        let endOffset = _content.index(offset(line: range.upperBound.line), offsetBy: range.upperBound.character)
        return _content[startOffset..<endOffset]
    }

    func string(in range: Swift.ClosedRange<Position>) -> Substring? {
        let startOffset = _content.index(offset(line: range.lowerBound.line), offsetBy: range.lowerBound.character)
        let endOffset = _content.index(offset(line: range.upperBound.line), offsetBy: range.upperBound.character)
        return _content[startOffset...endOffset]
    }

    func string(line lineIndex: Int) -> Substring {
        _content[lineRange(line: lineIndex)]
    }

    func character(at position: Position) -> Character? {
        let index = _content.index(offset(line: position.line), offsetBy: position.character)
        return _content[index]
    }

    func characterIndex(at position: Position) -> Int {
        let nsrange = NSRange(_content.startIndex..<offset(line: position.line), in: _content)
        return nsrange.location + nsrange.length + position.character
    }

    func position(atCharacterIndex characterIndex: Int) -> Position? {
        let stringCharacterIndex = _content.index(_content.startIndex, offsetBy: characterIndex, limitedBy: _content.endIndex)!
        guard let foundLine = _cacheLineRange.first(where: { $0.value.contains(stringCharacterIndex) }) else {
            return nil
        }

        let distance = _content.distance(from: foundLine.value.lowerBound, to: stringCharacterIndex)
        return Position(line: foundLine.key, character: distance)
    }

    private func offset(line lineIndex: Int) -> String.Index {
        lineRange(line: lineIndex).lowerBound
    }

    private func lineRange(line lineIndex: Int) -> Swift.Range<String.Index> {
        _cacheLineRange[lineIndex] ?? _content.startIndex..<_content.endIndex
    }

    private func invalidateLinesCache() {
        _cacheLineRange.removeAll(keepingCapacity: true)

        // nice try to use Algorithms, but it's slow ~180ms
        /*
        logger.trace("invalidateLinesCache chunksOfLines willStart")
        _content.chunksOfLines().enumerated().forEach { chunk in
            _cacheLineRange[chunk.offset] = chunk.element.indices.startIndex..<chunk.element.indices.endIndex
        }
        logger.trace("invalidateLinesCache chunksOfLines didEnd")
         */

        // Faster than Algorithms version, ~90ms, way slower in debug.
        /*
        do {
            logger.trace("invalidateLinesCache willStart")
            var currentLine = 0
            var lineStartIndex = _content.startIndex
            for currentIndex in _content.indices where _content[currentIndex].isNewline {
                let lineEndIndex = _content.index(after: currentIndex)
                _cacheLineRange[currentLine] = lineStartIndex..<lineEndIndex
                currentLine += 1
                lineStartIndex = lineEndIndex
            }

            _cacheLineRange[currentLine] = lineStartIndex..<_content.endIndex
            logger.trace("invalidateLinesCache didEnd")
        }
        */

        // StringProtocol.enumerateLines is fast! probably because gies with ObjC
        // This is fastest ~90ms in Debug and Release, but lack proper newlines
        logger.trace("invalidateLinesCache enumerateLines willStart")
        var currentLine = 0
        var lineStartIndex = _content.startIndex
        _content.enumerateLines { [unowned self] line, stop in
            // \n is 1 character, \r\n is 1 character at _content[lineEndIndex]
            // hence offset is line.count + 1; that is a line with trailing newline character
            if let lineEndIndex = _content.index(lineStartIndex, offsetBy: line.count + 1, limitedBy: _content.endIndex) {
                _cacheLineRange[currentLine] = lineStartIndex..<lineEndIndex
                currentLine += 1
                lineStartIndex = lineEndIndex
            }
        }
        _cacheLineRange[currentLine] = lineStartIndex..<_content.endIndex
        logger.trace("invalidateLinesCache enumerateLines didEnd (\(currentLine))")
    }
}
