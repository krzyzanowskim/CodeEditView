import Foundation

protocol TextStorageProvider {

    var linesCount: Int { get }
    
    func character(at position: Position) -> Character?
    func insert(string: String, at position: Position)
    func remove(range: Range)
    func string(in range: Swift.Range<Position>) -> String?
}
