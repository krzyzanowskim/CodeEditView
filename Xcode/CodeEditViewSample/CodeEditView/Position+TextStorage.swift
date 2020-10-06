import Foundation

extension Position {

    mutating func move(by charactersCount: Int, in textStorage: TextStorage) {
        if charactersCount > 0 {
            if let newPosition = position(after: UInt(charactersCount), in: textStorage) {
                self = newPosition
            }
        } else if charactersCount < 0 {
            if let newPosition = position(before: UInt(-charactersCount), in: textStorage) {
                self = newPosition
            }
        }
    }

    /// Return a Position after move by charactersOffset characters forward.
    /// - Parameters:
    ///   - charactersOffset: Characters count to move.
    ///   - textStorage: TextStorage to use.
    /// - Returns: New position, or nil when it's out of bounds.
    func position(after charactersOffset: UInt, in textStorage: TextStorage) -> Position? {
        var currentLinePosition = self
        var consumedCount = 0

        while consumedCount < charactersOffset {
            let currentLineString = textStorage.string(line: currentLinePosition.line)
            let newCharacterOffset = currentLinePosition.character + (Int(charactersOffset) - consumedCount)

            if newCharacterOffset < currentLineString.count {
                consumedCount += newCharacterOffset - currentLinePosition.character
                currentLinePosition = Position(line: currentLinePosition.line, character: newCharacterOffset)
            } else if currentLinePosition.line + 1 < textStorage.linesCount {
                consumedCount += currentLineString.count - (currentLinePosition.character + 1) + 1 // TODO: 1 for newline, will fail for \r\n and any other newline
                currentLinePosition = Position(line: currentLinePosition.line + 1, character: 0)
            } else {
                return nil
            }
        }
        return currentLinePosition
    }

    /// Return a Position after move by charactersOffset characters backward
    /// - Parameters:
    ///   - charactersOffset: Characters count to move.
    ///   - textStorage: TextStorage to use.
    /// - Returns: New position, or nil when it's out of bounds.
    func position(before charactersOffset: UInt, in textStorage: TextStorage) -> Position? {
        var currentLinePosition = self
        var consumedCount = 0

        while consumedCount < charactersOffset {
            let newCharacterOffset = currentLinePosition.character - (Int(charactersOffset) - consumedCount)

            if newCharacterOffset >= 0 {
                consumedCount += currentLinePosition.character - newCharacterOffset
                currentLinePosition = Position(line: currentLinePosition.line, character: newCharacterOffset)
            } else if currentLinePosition.line - 1 >= 0 {
                consumedCount += (currentLinePosition.character + 1) + 1 // TODO: 1 for newline, will fail for \r\n and any other newline
                let prevLineString = textStorage.string(line: currentLinePosition.line - 1)
                currentLinePosition = Position(line: currentLinePosition.line - 1, character: prevLineString.count - 1)
            } else {
                return nil
            }
        }
        return currentLinePosition
    }
}
