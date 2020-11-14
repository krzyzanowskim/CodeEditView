import Foundation
import Combine
import Cocoa

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    public let storageDidChange = PassthroughSubject<Range, Never>()
    internal let _textAttributes = TextAttributes() // TODO private
    private let _storageProvider: TextStorageProvider

    public var linesCount: Int {
        _storageProvider.linesCount
    }

    public init(string: String = "") {
        _storageProvider = StringTextStorageProvider()
        if !string.isEmpty {
            insert(string: string, at: Position(line: 0, character: 0))
        }
    }

    public func insert(string: String, at position: Position) {
        _storageProvider.insert(string: string, at: position)
        _textAttributes.adjustAttributedRanges(afterDidInsert: string, at: position, in: self)
        if let endPosition = position.position(after: 1, in: self) {
            storageDidChange.send(Range(start: position, end: endPosition))
        }
    }

    public func remove(range: Range) {
        _storageProvider.remove(range: range)
        _textAttributes.adjustAttributedRanges(didRemoveRange: range, in: self)
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
        _textAttributes.add(attribute, value, range)
    }
}
