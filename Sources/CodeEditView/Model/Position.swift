/// Position in a text document expressed as zero-based line and zero-based character offset
///
/// Positions are line end character agnostic. So you can not specify a position that denotes \r|\n or \n| where | represents the character offset.
/// [Langauge Server Specitication Position](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position)
public struct Position: Hashable, Equatable {
    /// Line position in a document (zero-based).
    public let line: Int
    /// Character offset on a line in a document (zero-based). Assuming that the line is
    /// represented as a string, the `character` value represents the gap between the
    /// `character` and `character + 1`.
    public let character: Int

    public static let zero = Position(line: 0, character: 0)

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

extension Position: Comparable {
    public static func < (lhs: Position, rhs: Position) -> Bool {
        if lhs.line < rhs.line {
            return true
        }

        if lhs.line > rhs.line {
            return false
        }

        return lhs.character < rhs.character
    }
}
