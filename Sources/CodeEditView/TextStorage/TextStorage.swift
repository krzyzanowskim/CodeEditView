import Foundation
import Combine
import Cocoa

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {

    /// Storage did chage publisher
    public let publisher = PassthroughSubject<Range, Never>()

    /// Whether text attribute ranges should update automatically on
    /// text storage mutations. Disabled by default to not interfere with
    /// an external systems that may want to update attributes instead.
    public var shouldUpdateAttributedRangesAutomatically: Bool

    internal let _textAttributes = TextAttributes() // TODO: Private
    private let _storageProvider: TextStorageProvider

    public var linesCount: Int {
        _storageProvider.linesCount
    }

    public init(string: String = "", shouldUpdateAttributedRangesAutomatically: Bool = false) {
        self.shouldUpdateAttributedRangesAutomatically = shouldUpdateAttributedRangesAutomatically
        _storageProvider = TextBufferStorageProvider() // StringTextStorageProvider()
        if !string.isEmpty {
            insert(string: string, at: Position(line: 0, character: 0))
        }
    }

    public func insert(string: String, at position: Position) {
        _textAttributes.processRangeInsert(string, at: position, in: self) {
            _storageProvider.insert(string: string, at: position)
        }
        
        if let endPosition = position.position(after: string.count, in: self) {
            publisher.send(Range(start: position, end: endPosition))
        }
    }

    public func remove(range: Range) {
        if shouldUpdateAttributedRangesAutomatically {
            _textAttributes.processRangeRemove(range, in: self) {
                _storageProvider.remove(range: range)
            }
        } else {
            _storageProvider.remove(range: range)
        }
        publisher.send(range)
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
