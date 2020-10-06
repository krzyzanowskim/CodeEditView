import Foundation


/// Layout mamager uses Top-bottom, left-right coordinate system to layout lines
class LayoutManager {

    typealias LineNumber = Int

    struct Metrics: Equatable {
        let ascent: CGFloat
        let descent: CGFloat
        let leading: CGFloat
        let width: CGFloat
        let height: CGFloat
        let lineSpacing: CGFloat
    }

    /// Cached layout. LayoutManager datasource.
    struct LineLayout: Equatable {
        /// Line index in store. Line number (zero based)
        /// In wrapping scenario, multiple LineLayouts for a single lineIndex.
        let lineNumber: LineNumber
        let ctline: CTLine
        /// A point that specifies the x and y values at which line is to be drawn.
        let origin: CGPoint
        let metrics: Metrics
        /// A string range of the line.
        /// For wrapped line its a fragment of the line.
        let stringRange: CFRange

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.lineNumber == rhs.lineNumber &&
                lhs.ctline == rhs.ctline &&
                lhs.origin == rhs.origin &&
                lhs.metrics == rhs.metrics &&
                lhs.stringRange.location == rhs.stringRange.location &&
                lhs.stringRange.length == rhs.stringRange.length
        }
    }

    /// Line spacing
    public enum LineSpacing: CGFloat {
        /// 0% line spacing
        case tight = 1.0
        /// 20% line spacing
        case normal = 1.2
        /// 40% line spacing
        case relaxed = 1.4
    }

    /// Line wrapping
    public enum LineWrapping {
        /// No wrapping
        case none
        /// Wrap at bounds
        case bounds
        /// Wrap at specific width
        case width(_ value: CGFloat = .infinity)
    }

    public struct Configuration {
        public var lineWrapping: LineWrapping = .none
        public var lineSpacing: LineSpacing = .normal
        public var wrapWords: Bool = true
        public var indentWrappedLines: Bool = true
    }

    public var configuration: Configuration

    private var _lineLayouts: [LineLayout]

    public init(_ configuration: Configuration = Configuration()) {
        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(500)

        self.configuration = configuration
    }

    public func caretBounds(at position: Position) -> CGRect? {
        guard let lineLayout = lineLayout(at: position) else {
            return nil
        }

        let metrics = lineLayout.metrics
        let characterOffsetX = CTLineGetOffsetForStringIndex(lineLayout.ctline, position.character, nil)
        return CGRect(x: lineLayout.origin.x + characterOffsetX,
                      y: lineLayout.origin.y - metrics.height - (metrics.lineSpacing / 2) + metrics.descent,
                      width: 20, //CTFontGetBoundingBox(font).width,
                      height: metrics.height + metrics.lineSpacing)
    }

    public func bounds(lineLayout: LineLayout) -> CGRect {
        let metrics = lineLayout.metrics
        let characterOffsetX = CTLineGetOffsetForStringIndex(lineLayout.ctline, 0, nil)
        return CGRect(x: lineLayout.origin.x + characterOffsetX,
                      y: lineLayout.origin.y - metrics.height - (metrics.lineSpacing / 2) + metrics.descent,
                      width: metrics.width,
                      height: metrics.height + metrics.lineSpacing)
    }

    // Index operation
    public func lineLayout(after lineLayout: LineLayout) -> LineLayout? {
        guard let idx = lineLayoutIndex(lineLayout) else {
            return nil
        }

        return self.lineLayout(idx: idx + 1)
    }

    // Index operation
    public func lineLayout(before lineLayout: LineLayout) -> LineLayout? {
        guard let idx = lineLayoutIndex(lineLayout), idx > 0 else {
            return nil
        }
        return self.lineLayout(idx: idx - 1)
    }

    public func lineLayout(idx: Int) -> LineLayout? {
        _lineLayouts[idx]
    }

    public func lineLayoutIndex(_ lineLayout: LineLayout) -> Int? {
        _lineLayouts.firstIndex(of: lineLayout)
    }

    public func lineLayout(at position: Position) -> LineLayout? {
        _lineLayouts.first { lineLayout -> Bool in
            position.character >= lineLayout.stringRange.location &&
                position.character < lineLayout.stringRange.location + lineLayout.stringRange.length &&
                position.line == lineLayout.lineNumber
        }
    }

    public func linesLayout(in rect: CGRect) -> [LineLayout] {
        _lineLayouts.filter { lineLayout in
            lineLayout.origin.y >= rect.minY && lineLayout.origin.y <= rect.maxY
        }
    }

    func layoutText(storage: TextStorage, font: CTFont, frame: CGRect) -> CGSize {
        logger.trace("layoutText willStart")
        // Let's layout some text. Top Bottom/Left Right
        // TODO: update layout
        // 1. find text range for displayed dirtyRect
        // 2. draw text from the range
        // 3. Layout only lines that meant to be displayed +- overscan

        // Largest content size needed to draw the lines
        var textContentSize = CGSize.zero

        let lineBreakWidth: CGFloat
        switch configuration.lineWrapping {
            case .none:
                lineBreakWidth = CGFloat.infinity
            case .bounds:
                lineBreakWidth = frame.width
            case .width(let width):
                lineBreakWidth = width
        }

        _lineLayouts.removeAll(keepingCapacity: true)

        // TopBottom/LeftRight
        var currentPos = CGPoint.zero
        for lineNumber in 0..<storage.linesCount {
            let lineString = storage.string(line: lineNumber)

            let attributedString = CFAttributedStringCreate(nil, lineString as CFString, [
                kCTFontAttributeName: font,
                kCTForegroundColorFromContextAttributeName: NSNumber(booleanLiteral: true)
            ] as CFDictionary)!
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)

            let indentWidth = configuration.indentWrappedLines ? CTFontGetSize(font) : 0

            var isWrappedLine = false
            var lineStartIndex: CFIndex = 0
            while lineStartIndex < lineString.count {
                if lineStartIndex > 0 {
                    isWrappedLine = true
                }

                let leadingIndent = isWrappedLine ? indentWidth : 0
                currentPos.x = leadingIndent

                let breakIndex: CFIndex
                if configuration.wrapWords {
                    breakIndex = CTTypesetterSuggestLineBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - leadingIndent), Double(currentPos.y))
                } else {
                    breakIndex = CTTypesetterSuggestClusterBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - leadingIndent), Double(currentPos.y))
                }
                let stringRange = CFRange(location: lineStartIndex, length: breakIndex)

                // Bottleneck
                let ctline = CTTypesetterCreateLineWithOffset(typesetter, stringRange, Double(currentPos.x))

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading)) + leadingIndent
                let lineHeight = ascent + descent + leading
                let lineSpacing = (lineHeight * configuration.lineSpacing.rawValue) - lineHeight

                // font origin based position
                _lineLayouts.append(
                    LineLayout(lineNumber: LineNumber(lineNumber),
                               ctline: ctline,
                               origin: CGPoint(x: currentPos.x, y: currentPos.y + ascent + descent),
                               metrics: Metrics(ascent: ascent,
                                                descent: descent,
                                                leading: leading,
                                                width: lineWidth,
                                                height: lineHeight,
                                                lineSpacing: lineSpacing),
                               stringRange: stringRange)
                )

                lineStartIndex += breakIndex
                currentPos.y += lineHeight + lineSpacing

                textContentSize.width = max(textContentSize.width, lineWidth)
            }
        }

        textContentSize.height = currentPos.y
        logger.trace("layoutText didEnd")
        return textContentSize
    }
}
