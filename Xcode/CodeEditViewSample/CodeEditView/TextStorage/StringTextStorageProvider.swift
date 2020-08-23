import Foundation

/// Dummy String based storage provider
class StringTextStorageProvider: TextStorageProvider {
    private var content: String = ""

    var linesCount: Int {
        content.split(separator: "\n").count
    }

    func character(at position: Position) -> Character? {
        let index = content.index(offset(line: position.line), offsetBy: position.character)
        return content[index]
    }

    func insert(string: String, at position: Position) {
        let index = content.index(offset(line: position.line), offsetBy: position.character)
        content.insert(contentsOf: string, at: index)
    }

    func remove(range: Range) {
        let startIndex = content.index(offset(line: range.start.line), offsetBy: range.start.character)
        let endIndex = content.index(offset(line: range.end.line), offsetBy: range.end.character)
        content.removeSubrange(startIndex..<endIndex)
    }

    func string(in range: Swift.Range<Position>) -> String? {
        let startOffset = content.index(offset(line: range.lowerBound.line), offsetBy: range.lowerBound.character)
        let endOffset = content.index(offset(line: range.upperBound.line), offsetBy: range.upperBound.character)
        return String(content[startOffset..<endOffset])
    }

    private func offset(line: Int) -> String.Index {
        if line == 0 {
            return content.startIndex
        }

        var currentLine = 0
        for (characterIdx, value) in content.enumerated() where value == "\n" {
            currentLine += 1
            if currentLine == line {
                return content.index(content.startIndex, offsetBy: characterIdx)
            }
        }

        return content.endIndex
    }
}
