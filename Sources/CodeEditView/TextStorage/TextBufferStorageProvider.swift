import Foundation
import TextBufferKit

class TextBufferStorageProvider: TextStorageProvider {
    private let pieceTree: PieceTreeTextBuffer

    var linesCount: Int {
        pieceTree.lineCount
    }

    init() {
        pieceTree = PieceTreeTextBufferBuilder()
            .finish(normalizeEol: true)
            .create(.LF)
    }

    func character(at position: Position) -> Character? {
        let lineString = String(decoding: pieceTree.getLineContent(position.line + 1), as: UTF8.self)
        let index = lineString.index(lineString.startIndex, offsetBy: position.character)
        return lineString[index]
    }

    func insert<S: StringProtocol>(string: S, at position: Position) {
        // obviously this is wrong because columns != character
        // let offset = pieceTree.getOffsetAt(lineNumber: position.line, column: position.character)
        pieceTree.insert(offset: offset(position: position), value: Array(string.utf8))
    }

    func remove(range: Range) {
        let startOffset = offset(position: range.start)
        let endOffset = offset(position: range.end)
        pieceTree.delete(offset: startOffset, count: endOffset - startOffset)
    }

    func string(in range: Swift.Range<Position>) -> Substring? {
        nil
    }

    func string(in range: ClosedRange<Position>) -> Substring? {
        nil
    }

    func string(line lineIndex: Int) -> Substring {
        let content = pieceTree.getLineContent(lineIndex + 1)
        if content.isEmpty {
            return "\n"
        }
        return Substring(decoding: pieceTree.getLineContent(lineIndex + 1), as: UTF8.self)
    }

    func characterIndex(at position: Position) -> Int {
        let offset = offset(position: position)
        return String(decoding: pieceTree.getLinesRawContent()[..<offset], as: UTF8.self).count
    }

    func position(atCharacterIndex characterIndex: Int) -> Position? {
        let content = String(decoding: pieceTree.getLinesRawContent(), as: UTF8.self)

        guard let contentCharacterIndex = content.index(content.startIndex, offsetBy: characterIndex, limitedBy: content.endIndex) else {
            return nil
        }

        // Find position in pieceTree
        let pieceTreePosition = pieceTree.getPositionAt(offset: Array<UInt8>(content[..<contentCharacterIndex].utf8).count)

        // Find the character index of the start of the line
        let positionLine = pieceTreePosition.line - 1

        // Get a string index of the start of the line
        let bzz = self.characterIndex(at: Position(line: positionLine, character: 0))
        let lineStartIndex = content.index(content.startIndex, offsetBy: bzz)

        // Get a character position in the line
        let distance = content.distance(from: lineStartIndex, to: contentCharacterIndex)
        return Position(line: positionLine, character: distance)
    }

    /// Position to offset in PieceTree
    private func offset(position: Position) -> Int {
        let lineString = String(decoding: pieceTree.getLineContent(position.line + 1), as: UTF8.self)
        let lineBeginOffset = pieceTree.getOffsetAt(lineNumber: position.line + 1, column: 1)
        let lineCharacterIndex = lineString.index(lineString.startIndex, offsetBy: position.character)
        return lineBeginOffset + Array<UInt8>(lineString[..<lineCharacterIndex].utf8).count
    }
}
