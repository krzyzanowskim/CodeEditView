import Foundation

/// Dummy String based storage provider
class StringTextStorageProvider: TextStorageProvider {
    private var _content: String = "" {
        didSet {
            invalidateLinesCache()
        }
    }
    private var _cacheLineRange: [Int: Swift.Range<String.Index>] = [:]

    var linesCount: Int {
        _cacheLineRange.count
    }

    func character(at position: Position) -> Character? {
        let index = _content.index(offset(line: position.line), offsetBy: position.character)
        return _content[index]
    }

    func insert(string: String, at position: Position) {
        let index = _content.index(offset(line: position.line), offsetBy: position.character)
        _content.insert(contentsOf: string, at: index)
    }

    func remove(range: Range) {
        let startIndex = _content.index(offset(line: range.start.line), offsetBy: range.start.character)
        let endIndex = _content.index(offset(line: range.end.line), offsetBy: range.end.character)
        _content.removeSubrange(startIndex...endIndex)
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

    func positionOffset(at position: Position) -> Int {
        let nsrange = NSRange(_content.startIndex..<offset(line: position.line), in: _content)
        return nsrange.location + nsrange.length + position.character
    }

    private func offset(line lineIndex: Int) -> String.Index {
        lineRange(line: lineIndex).lowerBound
    }

    private func lineRange(line lineIndex: Int) -> Swift.Range<String.Index> {
        _cacheLineRange[lineIndex] ?? _content.startIndex..<_content.endIndex
    }

    private func invalidateLinesCache() {
        _cacheLineRange.removeAll(keepingCapacity: true)

        var currentLine = 0
        var lineStartIndex = _content.startIndex
        for currentIndex in _content.indices where _content[currentIndex].isNewline {
            let lineEndIndex = _content.index(after: currentIndex)
            _cacheLineRange[currentLine] = lineStartIndex..<lineEndIndex
            currentLine += 1
            lineStartIndex = lineEndIndex
        }

        _cacheLineRange[currentLine] = lineStartIndex..<_content.endIndex
    }
}

// MARK - Tests

#if canImport(XCTest)
import XCTest

class StringTextStorageProviderTests: XCTestCase {

    func testProvider() {
        let storageProvider = StringTextStorageProvider()
        XCTAssertEqual(storageProvider.linesCount, 0)
        storageProvider.insert(string: "test", at: Position(line: 0, character: 0))
        XCTAssertEqual(storageProvider.linesCount, 1)
        XCTAssertEqual(storageProvider.character(at: Position(line: 0, character: 1)), "e")
    }

    func testRemove1() {
        let storageProvider = StringTextStorageProvider()
        storageProvider.insert(string: "test", at: Position(line: 0, character: 0))
        XCTAssertEqual(storageProvider.string(line: 0), "test")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(storageProvider.string(line: 0), "est")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(storageProvider.string(line: 0), "st")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(storageProvider.string(line: 0), "t")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(storageProvider.string(line: 0), "")
    }

    func testPositionOffset() {
        let storageProvider = StringTextStorageProvider()
        storageProvider.insert(string: "test\ntest2\ntest3", at: Position(line: 0, character: 0))
        let index = storageProvider.positionOffset(at: Position(line: 2, character: 2))
        XCTAssertEqual(index, 13)
    }
}
#endif
