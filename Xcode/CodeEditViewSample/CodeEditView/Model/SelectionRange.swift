public class SelectionRange: Hashable, Equatable {
    /// The range of this selection range.
    var range: Range
    /// The parent selection range containing this range. Therefore `parent.range` must contain `this.range`.
    var parent: SelectionRange?

    init(_ range: Range, parent: SelectionRange? = nil) {
        self.range = range
        self.parent = parent
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(range)
        hasher.combine(parent)
    }

    public static func == (lhs: SelectionRange, rhs: SelectionRange) -> Bool {
        lhs.range == rhs.range &&
            lhs.parent == rhs.parent
    }
}
