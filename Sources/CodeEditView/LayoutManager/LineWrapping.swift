import CoreGraphics

/// Line wrapping
public enum LineWrapping {
    /// No wrapping
    case none
    /// Wrap at bounds
    case bounds
    /// Wrap at specific width
    case width(_ value: CGFloat = .infinity)
}
