import Foundation


/// Layout mamager uses Top-bottom, left-right coordinate system to layout lines
class LayoutManager {

    typealias LineNumber = Int

    /// Cached layout. LayoutManager datasource.
    struct LineLayout: Equatable {
        /// Line index in store. Line number (zero based)
        /// In wrapping scenario, multiple LineLayouts for a single lineIndex.
        let lineNumber: LineNumber
        let ctline: CTLine
        /// A line origin
        //let origin: CGPoint
        /// A line baseline
        let baseline: CGPoint
        let bounds: CGRect
        let lineSpacing: CGFloat
        /// A string range of the line.
        /// For wrapped line its a fragment of the line.
        let stringRange: CFRange

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.lineNumber == rhs.lineNumber &&
            lhs.ctline == rhs.ctline &&
            lhs.baseline == rhs.baseline &&
            lhs.bounds == rhs.bounds &&
            lhs.lineSpacing == rhs.lineSpacing &&
            lhs.stringRange == rhs.stringRange
        }
    }

    struct Configuration {
        /// Line wrapping mode.
        var lineWrapping: LineWrapping = .none
        /// Wrap on words.
        var wrapWords: Bool = true
        /// Indent wrapped lines.
        var indentWrappedLines: Bool = true
        /// Indentation level.
        var indentLevel: Int = 2
        /// Line spacing style.
        var lineSpacing: LineSpacing = .normal
    }

    var configuration: Configuration

    private var _lineLayouts: [LineLayout]
    private var _textStorage: TextStorage
    private var _invalidLayoutLineNumbers: Set<LineNumber>

    init(configuration: Configuration, textStorage: TextStorage) {
        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(500)
        self._textStorage = textStorage
        self._invalidLayoutLineNumbers = []

        self.configuration = configuration
    }

    // MARK: - Metrics

    func caretBounds(at position: Position) -> CGRect? {
        guard let lineLayout = lineLayout(at: position) else {
            return nil
        }

        let characterOffsetX = CTLineGetOffsetForStringIndex(lineLayout.ctline, position.character, nil)
        var rect = lineLayout.bounds.offsetBy(dx: characterOffsetX, dy: 0)
        // arbitrary number that should be replaced for the font width
        rect.size.width = 20
        return rect
    }

    // MARK: - Fetch LineLayout

    func lineLayout(after lineLayout: LineLayout) -> LineLayout? {
        guard let idx = lineLayoutIndex(lineLayout) else {
            return nil
        }

        return self.lineLayout(idx: idx + 1)
    }


    func lineLayout(before lineLayout: LineLayout) -> LineLayout? {
        guard let idx = lineLayoutIndex(lineLayout), idx > 0 else {
            return nil
        }
        return self.lineLayout(idx: idx - 1)
    }

    func lineLayout(idx: Int) -> LineLayout? {
        // TODO: layout if missing
        _lineLayouts[idx]
    }

    func lineLayoutIndex(_ lineLayout: LineLayout) -> Int? {
        // TODO: try to layout if missing
        _lineLayouts.firstIndex(of: lineLayout)
    }

    func lineLayout(at position: Position) -> LineLayout? {
        // TODO: try to layout if missing
        _lineLayouts.first { lineLayout -> Bool in
            position.character >= lineLayout.stringRange.location &&
                position.character < lineLayout.stringRange.location + lineLayout.stringRange.length &&
                position.line == lineLayout.lineNumber
        }
    }

    func lineLayout(at point: CGPoint) -> LineLayout? {
        // TODO: try to layout if missing
        _lineLayouts.first { lineLayout in
            let visibleLineBounds = lineLayout.bounds.insetBy(dx: 0, dy: -lineLayout.lineSpacing / 2)
            let lowerBound = visibleLineBounds.origin.y
            let upperBound = lowerBound.advanced(by: visibleLineBounds.height)
            return (lowerBound...upperBound).contains(point.y)
        }
    }

    func linesLayouts(in rect: CGRect) -> [LineLayout] {
        // TODO: try to layout if missing
        _lineLayouts.filter { lineLayout in
            rect.intersects(lineLayout.bounds)
        }
    }

    // so slow. sooo slow. O(n)
    // Can be fast by change [LineLayout] -> [LineNumber: LineLayout]
    func lineLayouts(forLineNumber lineNumber: LineNumber) -> ArraySlice<LayoutManager.LineLayout> {
        let predicate: (LineLayout) -> Bool = { $0.lineNumber == lineNumber }

        guard let firstIndex = _lineLayouts.firstIndex(where: predicate) else {
            return []
        }

        for i in firstIndex..<_lineLayouts.endIndex {
            if !predicate(_lineLayouts[i]) {
                return _lineLayouts[firstIndex..<i]
            }
        }

        return []
    }

    // MARK: -

    /// Mark line layout invalid. Layout will update on next call to `layoutText`
    func invalidateLayout(lineNumber: LineNumber) {
        _invalidLayoutLineNumbers.formUnion(
            lineLayouts(forLineNumber: lineNumber).map(\.lineNumber)
        )
    }

    /// Mark line layout valid.
    func validateLayout(lineNumber: LineNumber) {
        _invalidLayoutLineNumbers.formIntersection(
            lineLayouts(forLineNumber: lineNumber).map(\.lineNumber)
        )
    }

    // MARK: -

    func layoutText(font: CTFont, frame: CGRect) -> CGSize {
        logger.trace("layoutText willStart, frame: \(NSStringFromRect(frame))")
        // Let's layout some text. Top Bottom/Left Right
        // TODO: update layout
        // 1. find text range for displayed dirtyRect
        // 2. draw text from the range
        // 3. Layout only lines that meant to be displayed +- overscan

        let lineBreakWidth: CGFloat
        switch configuration.lineWrapping {
            case .none:
                lineBreakWidth = CGFloat.infinity
            case .bounds:
                lineBreakWidth = frame.width
            case .width(let width):
                lineBreakWidth = width
        }

        let indentWidth = configuration.indentWrappedLines ? (CTFontGetBoundingBox(font).width * CGFloat(configuration.indentLevel)) : 0
        var currentPos = CGPoint.zero

        // TopBottom/LeftRight
        // estimate text content size
        _lineLayouts.removeAll(keepingCapacity: true)
        var textContentSize = CGSize(width: frame.width, height: CGFloat(_textStorage.linesCount) * CTFontGetBoundingBox(font).height)

        for lineNumber in 0..<_textStorage.linesCount {
            let lineString = _textStorage.string(line: lineNumber)

            let attributedString = CFAttributedStringCreate(nil, lineString as CFString, [
                kCTFontAttributeName: font,
                kCTForegroundColorFromContextAttributeName: NSNumber(booleanLiteral: true)
            ] as CFDictionary)!
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)

            var isWrappedLine = false
            var lineStartIndex: CFIndex = 0
            while lineStartIndex < lineString.count {
                if lineStartIndex > 0 {
                    isWrappedLine = true
                }

                // Indent wrapped line
                currentPos.x = isWrappedLine ? indentWidth : 0

                let breakIndex: CFIndex
                if configuration.wrapWords {
                    breakIndex = CTTypesetterSuggestLineBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - currentPos.x), Double(currentPos.x))
                } else {
                    breakIndex = CTTypesetterSuggestClusterBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - currentPos.x), Double(currentPos.x))
                }
                let stringRange = CFRange(location: lineStartIndex, length: breakIndex)

                // Bottleneck
                let ctline = CTTypesetterCreateLineWithOffset(typesetter, stringRange, Double(currentPos.x))

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading))
                let lineHeight = (ascent + descent + leading).rounded(.awayFromZero)
                let lineSpacing = (lineHeight * configuration.lineSpacing.rawValue).rounded(.awayFromZero)

                // first line
                if currentPos == .zero {
                    currentPos.y = lineSpacing / 2
                }

                // font origin based position
                _lineLayouts.append(
                    LineLayout(lineNumber: LineNumber(lineNumber),
                               ctline: ctline,
                               baseline: CGPoint(x: 0, y: ascent),
                               bounds: CGRect(x: currentPos.x,
                                              y: currentPos.y,
                                              width: lineWidth,
                                              height: lineHeight
                               ),
                               lineSpacing: lineSpacing,
                               stringRange: stringRange)
                )

                lineStartIndex += breakIndex
                currentPos.y += lineHeight + lineSpacing

                textContentSize.width = max(textContentSize.width, lineWidth)
            }
            // validateLayout(lineNumber: lineNumber)
        }

        textContentSize.height = max(textContentSize.height, currentPos.y)
        logger.trace("layoutText didEnd, contentSize: \(NSStringFromSize(textContentSize))")

        return textContentSize
    }
}
