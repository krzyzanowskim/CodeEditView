import Foundation

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    private let storageProvider: TextStorageProvider

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
    }

    public func remove(range: Range) {
        storageProvider.remove(range: range)
    }

    public subscript(_ position: Position) -> Character? {
        storageProvider.character(at: position)
    }

    public subscript(_ range: Swift.Range<Position>) -> Substring? {
        storageProvider.string(in: range)
    }

    public subscript(_ range: Swift.ClosedRange<Position>) -> Substring? {
        storageProvider.string(in: range)
    }

    public subscript(line idx: Int) -> Substring {
        storageProvider.string(line: idx)
    }
}
