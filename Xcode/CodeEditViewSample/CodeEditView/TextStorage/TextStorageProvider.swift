import Foundation

protocol TextStorageProvider {
    func character(at position: Position) -> Character?
    func insert(string: String, at position: Position)
    func remove(range: Range)
    func string(in range: Swift.Range<Position>) -> String?
}

class RopeTextStorageProvider: TextStorageProvider {

    func character(at position: Position) -> Character? {
        return nil
    }

    func insert(string: String, at position: Position) {
        // TODO
    }

    func remove(range: Range) {
        // TODO
    }

    func string(in range: Swift.Range<Position>) -> String? {
        return nil
    }

}
