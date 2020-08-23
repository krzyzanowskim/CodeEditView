import Foundation

class RopeTextStorageProvider: TextStorageProvider {

    var linesCount: Int = 0

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
