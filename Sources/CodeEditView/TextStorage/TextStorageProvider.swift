import Foundation

protocol TextStorageProvider {

    var linesCount: Int { get }
    
    func character(at position: Position) -> Character?
    func insert(string: String, at position: Position)
    /// Remove content at range
    func remove(range: Range)
    func string(in range: Swift.Range<Position>) -> Substring?
    func string(in range: Swift.ClosedRange<Position>) -> Substring?
    func string(line idx: Int) -> Substring
    /// Character offset in a document for a position
    func characterIndex(at position: Position) -> Int
    func position(atCharacterIndex: Int) -> Position?
}
