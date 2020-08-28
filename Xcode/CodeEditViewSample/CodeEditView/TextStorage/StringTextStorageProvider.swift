import Foundation

/// Dummy String based storage provider
class StringTextStorageProvider: TextStorageProvider {
    private var content: String = ""

    var linesCount: Int {
        content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
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
        content.removeSubrange(startIndex...endIndex)
    }

    func string(in range: Swift.Range<Position>) -> Substring? {
        let startOffset = content.index(offset(line: range.lowerBound.line), offsetBy: range.lowerBound.character)
        let endOffset = content.index(offset(line: range.upperBound.line), offsetBy: range.upperBound.character)
        return content[startOffset..<endOffset]
    }

    func string(in range: Swift.ClosedRange<Position>) -> Substring? {
        let startOffset = content.index(offset(line: range.lowerBound.line), offsetBy: range.lowerBound.character)
        let endOffset = content.index(offset(line: range.upperBound.line), offsetBy: range.upperBound.character)
        return content[startOffset...endOffset]
    }

    func string(line lineIndex: Int) -> Substring {
        content[lineRange(line: lineIndex)]
    }

    private func offset(line lineIndex: Int) -> String.Index {
        lineRange(line: lineIndex).lowerBound
    }

    private func lineRange(line lineIndex: Int) -> Swift.Range<String.Index> {
        var lineStartIndex = content.startIndex
        var lineEndIndex = content.startIndex
        var currentLine = 0

        while lineStartIndex <= content.endIndex && currentLine <= lineIndex {
            if let newlineIndex = content[lineStartIndex...].firstIndex(where: \.isNewline) {
                lineEndIndex = content.index(after: newlineIndex)
            } else {
                lineEndIndex = content.endIndex
            }

            if currentLine == lineIndex {
                return lineStartIndex..<lineEndIndex
            }

            currentLine += 1
            lineStartIndex = lineEndIndex
        }

        return content.startIndex..<content.endIndex
    }
}
