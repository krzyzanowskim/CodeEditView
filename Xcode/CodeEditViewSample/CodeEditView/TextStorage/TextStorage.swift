import Foundation
import Combine
import Cocoa

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    internal var _attributedRanges: [Range: [PartialKeyPath<String.AttributeKey>: Any]] = [:]
    private let _storageProvider: TextStorageProvider
    let storageDidChange = PassthroughSubject<Range, Never>()

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
        storageDidChange.send(Range(position))
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
        if var attributes = _attributedRanges[range] {
            attributes[attribute] = value
            _attributedRanges[range] = attributes
        } else {
            _attributedRanges[range] = [attribute: value]
        }
    }

    public func attribute<Value>(_ attribute: KeyPath<String.AttributeKey, Value>, in range: Range) -> (Value, Range)? {
        for (r, attributes) in _attributedRanges where r.intersects(range) {
            guard let anyValue = attributes[\String.AttributeKey.foreground] else {
                continue
            }
            return (anyValue as! Value, r)
        }
        return nil
    }
}
