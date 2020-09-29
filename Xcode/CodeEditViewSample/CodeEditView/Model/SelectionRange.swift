public class SelectionRange {
    /// The range of this selection range.
    var range: Range
    /// The parent selection range containing this range. Therefore `parent.range` must contain `this.range`.
    var parent: SelectionRange?

    init(_ range: Range, parent: SelectionRange? = nil) {
        self.range = range
        self.parent = parent
    }
}
