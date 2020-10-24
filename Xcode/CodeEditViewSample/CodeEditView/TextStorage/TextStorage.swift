import Foundation
import Combine

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    private let storageProvider: TextStorageProvider
    let storageDidChange = PassthroughSubject<Range, Never>()

    public var linesCount: Int {
        storageProvider.linesCount
    }

    public init(string: String = "") {
        storageProvider = StringTextStorageProvider()
        if !string.isEmpty {
            insert(string: string, at: Position(line: 0, character: 0))
        }
    }

    public func insert(string: String, at position: Position) {
        storageProvider.insert(string: string, at: position)
        storageDidChange.send(Range(start: position, end: position))
    }

    public func remove(range: Range) {
        storageProvider.remove(range: range)
        storageDidChange.send(range)
    }

    public func character(at position: Position) -> Character? {
        storageProvider.character(at: position)
    }

    public func characterIndex(at position: Position) -> Int {
        storageProvider.characterIndex(at: position)
    }

    public func string(in range: Range) -> Substring? {
        storageProvider.string(in: range.start..<range.end)
    }

    public func string(in range: Swift.Range<Position>) -> Substring? {
        storageProvider.string(in: range)
    }

    public func string(in range: Swift.ClosedRange<Position>) -> Substring? {
        storageProvider.string(in: range)
    }

    public func string(line idx: Int) -> Substring {
        storageProvider.string(line: idx)
    }
}
