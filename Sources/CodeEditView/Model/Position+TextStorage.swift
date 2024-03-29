import Foundation

extension Position {
    /// Visually move one line down
    mutating func moveDownByLine(using layoutManager: LayoutManager) {
        guard let currentLineCaretBounds = layoutManager.caretBounds(at: self),
              let currentLineLayout = layoutManager.lineLayout(at: self),
              let nextLinePosition = layoutManager.position(at: currentLineCaretBounds.origin.applying(.init(translationX: 0, y: currentLineLayout.bounds.height + currentLineLayout.lineSpacing)))
        else {
            return
        }

        self = nextLinePosition
    }

    /// Visually move one line up
    mutating func moveUpByLine(using layoutManager: LayoutManager) {
        guard let currentLineCaretBounds = layoutManager.caretBounds(at: self),
              let currentLineLayout = layoutManager.lineLayout(at: self),
              let prevLinePosition = layoutManager.position(at: currentLineCaretBounds.origin.applying(.init(translationX: 0, y: -(currentLineLayout.bounds.height + currentLineLayout.lineSpacing))))
        else {
            return
        }

        self = prevLinePosition
    }

    /// Move position by number of characters.
    /// - Parameters:
    ///   - charactersCount: Count of characters to move by.
    ///   - textStorage: TextStorage.
    mutating func move(by charactersCount: Int, in textStorage: TextStorage) {
        guard let newPosition = moved(by: charactersCount, in: textStorage) else {
            return
        }
        self = newPosition
    }

    private func moved(by charactersCount: Int, in textStorage: TextStorage) -> Self? {
        if charactersCount > 0 {
            if let newPosition = position(after: charactersCount, in: textStorage) {
                return newPosition
            }
        } else if charactersCount < 0 {
            if let newPosition = position(before: -charactersCount, in: textStorage) {
                return newPosition
            }
        }
        return nil
    }

    /// Return a Position after move by charactersOffset characters forward.
    /// - Parameters:
    ///   - charactersOffset: Characters count to move.
    ///   - textStorage: TextStorage to use.
    /// - Returns: New position, or nil when it's out of bounds.
    func position(after charactersOffset: Int, in textStorage: TextStorage) -> Position? {
        var currentLinePosition = self
        var consumedCount = 0

        while consumedCount < charactersOffset {
            let currentLineString = textStorage.string(line: currentLinePosition.line)
            let newCharacterIndex = currentLinePosition.character + (Int(charactersOffset) - consumedCount)

            if newCharacterIndex < currentLineString.count {
                consumedCount += newCharacterIndex - currentLinePosition.character
                currentLinePosition = Position(line: currentLinePosition.line, character: newCharacterIndex)
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
    func position(before charactersOffset: Int, in textStorage: TextStorage) -> Position? {
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
