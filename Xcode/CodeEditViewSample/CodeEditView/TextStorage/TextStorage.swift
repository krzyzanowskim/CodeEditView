import Foundation

/// Text Storage
/// TODO: notify about updates via delegate or callbacks
public final class TextStorage {
    private let storageProvider: TextStorageProvider

    public init(string: String = "") {
        storageProvider = RopeTextStorageProvider()
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

    public subscript(_ range: Swift.Range<Position>) -> String? {
        storageProvider.string(in: range)
    }
}
