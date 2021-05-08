import Foundation
import Combine
import Cocoa

// FIXME: Position is newline agnostic, but TextStorage is not! and can't be.
//        Line should be a string without newline, yet TextStorage need to know
//        about the newline to properly find a range in a raw buffer

/// Layout mamager uses Top-bottom, left-right coordinate system to layout lines
class LayoutManager {

    typealias LineNumber = Int

    /// Cached layout. LayoutManager datasource.
    struct LineLayout: Equatable, Hashable {
        // TODO: CoW

        /// Line index in store. Line number (zero based)
        /// In wrapping scenario, multiple LineLayouts for a single lineIndex.
        let lineNumber: LineNumber

        // Note: After inserting an instance of a reference type into a set,
        //       the properties of that instance must not be modified in a way
        //       that affects its hash value or testing for equality.
        //       This is why can't really use it in a Set.
        let ctline: CTLine
        /// A line baseline
        let baseline: CGPoint
        let bounds: CGRect
        let lineSpacing: CGFloat
        /// A string range of the line, related to the real line (lineNumber).
        /// For soft wrapped line its a fragment of the line.
        let stringRange: CFRange
    }


    enum Overscroll {
        case none
        case automatic
        case height(CGFloat)
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
        /// Overscroll
        var overscroll: Overscroll = .automatic
    }

    var configuration: Configuration

    private var _lineLayouts: [LineLayout]
    private var _textStorage: TextStorage
    private var _invalidRanges: Set<Range>
    private var _cancellables: Set<AnyCancellable>

    init(configuration: Configuration, textStorage: TextStorage) {
        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(2048)
        self._textStorage = textStorage
        self._invalidRanges = Set(minimumCapacity: 2048)
        self._cancellables = []

        self.configuration = configuration

        textStorage.publisher
            .sink(receiveValue: invalidateLayout)
            .store(in: &_cancellables)
    }

    private func invalidateLayout(range: Range) {
        logger.debug("invalidateLayout insert \(range)")
        _invalidRanges.insert(range)
    }

    // MARK: - Metrics

    func caretBounds(at position: Position) -> CGRect? {
        guard let lineLayout = lineLayout(at: position) else {
            return nil
        }

        //var characterOffsetX: CGFloat = 0
        //CTLineEnumerateCaretOffsets(lineLayout.ctline) { (offset, charIndex, leadingEdge, stop) in
        //    if charIndex == position.character {
        //        characterOffsetX = CGFloat(offset)
        //        stop.pointee = true
        //    }
        //}
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

        return self.lineLayout(index: idx + 1)
    }


    func lineLayout(before lineLayout: LineLayout) -> LineLayout? {
        guard let idx = lineLayoutIndex(lineLayout), idx > 0 else {
            return nil
        }
        return self.lineLayout(index: idx - 1)
    }

    func lineLayout(index: Int) -> LineLayout? {
        guard index < _lineLayouts.count else {
            return nil
        }
        return _lineLayouts[index]
    }

    func lineLayoutIndex(_ lineLayout: LineLayout) -> Int? {
        _lineLayouts.firstIndex(of: lineLayout)
    }

    func lineLayout(at position: Position) -> LineLayout? {
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
        _lineLayouts.lazy.filter { lineLayout in
            rect.intersects(lineLayout.bounds)
        }
    }

    func position(at point: CGPoint) -> Position? {
        guard let lineLayout = lineLayout(at: point) else {
            return nil
        }

        // adjust line inset offset
        let insetAdjustedPoint = point.applying(.init(translationX: -lineLayout.bounds.origin.x , y: 0))
        let characterIndex = CTLineGetStringIndexForPosition(lineLayout.ctline, insetAdjustedPoint)
        guard characterIndex != kCFNotFound else {
            return nil
        }

        let character = max(0, min(lineLayout.stringRange.location + lineLayout.stringRange.length - 1, characterIndex))
        return Position(line: lineLayout.lineNumber, character: character) // -1 because newline character. (or is it?)
    }

    // so slow. sooo slow. O(n)
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

    func layoutText(font: CTFont, color: CGColor, frame: CGRect) -> CGSize {
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

        let indentWidth = configuration.indentWrappedLines ? floor((CTFontGetBoundingBox(font).width * CGFloat(configuration.indentLevel)) + 0.5) : 0

        // TopBottom/LeftRight
        // let firstInvalidLineNumber = _invalidRanges.min()?.start.line ?? 0
        // let lastInvalidLineNumber = _invalidRanges.max()?.end.line ?? 0
        // var currentPos: CGPoint = lineLayouts(forLineNumber: firstInvalidLineNumber).first?.bounds.origin ?? .zero
        var currentPos: CGPoint = .zero

        // estimate text content size
        var textContentSize = CGSize.zero //CGSize(width: frame.width, height: floor(CGFloat(_textStorage.linesCount) * CTFontGetBoundingBox(font).height) + 0.5)

        var lineLayoutsRun: [LineLayout] = []
        lineLayoutsRun.reserveCapacity(_lineLayouts.underestimatedCount)

//        // get all invalid lines
//        let invalidLineNumbers = _invalidRanges.reduce(into: Set<LineNumber>()) { result, range in
//            result.formUnion(range.start.line...range.end.line)
//        }
//
        // Iterate over invalid lines
        for lineNumber in 0..<_textStorage.linesCount {

            // Copy valid lines
//            if !invalidLineNumbers.contains(lineNumber) {
//                let existingLayouts = lineLayouts(forLineNumber: lineNumber)
//                if !existingLayouts.isEmpty {
//                    lineLayoutsRun.append(contentsOf: existingLayouts)
//
//                    let height = existingLayouts.reduce(0) { result, lineLayout in
//                        result + lineLayout.bounds.height + lineLayout.lineSpacing
//                    }
//
//                    // First line
//                    if currentPos == .zero, let firstLine = _lineLayouts.first {
//                        currentPos.y = floor((firstLine.lineSpacing / 2) + 0.5)
//                    }
//
//                    currentPos.y += height
//                    continue
//                }
//            }

            // Update invalid lines
            // logger.debug("actual layout \(lineNumber)")

            let lineString = _textStorage.string(line: lineNumber)
            let attributedString = createAttributedString(lineNumber: lineNumber, lineString: lineString, defaultFont: font, defaultColor: color)
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
                let lineWidth = CGFloat(floor(CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading) + 0.5))
                let lineHeight = floor((ascent + descent + leading) + 0.5)
                let lineSpacing = floor((lineHeight * configuration.lineSpacing.rawValue) + 0.5)

                // first line
                if currentPos == .zero {
                    currentPos.y = floor((lineSpacing / 2) + 0.5)
                }

                // font origin based position
                let lineLayout = LineLayout(lineNumber: LineNumber(lineNumber),
                               ctline: ctline,
                               baseline: CGPoint(x: 0, y: ascent),
                               bounds: CGRect(x: currentPos.x,
                                              y: currentPos.y,
                                              width: lineWidth,
                                              height: lineHeight
                               ),
                               lineSpacing: lineSpacing,
                               stringRange: stringRange)

                lineLayoutsRun.append(lineLayout)

                lineStartIndex += breakIndex
                currentPos.y += lineHeight + lineSpacing

                textContentSize.width = max(textContentSize.width, lineWidth)
            }
        }

        _lineLayouts.removeAll(keepingCapacity: true)
        _lineLayouts.append(contentsOf: lineLayoutsRun)

        var overscroll: CGFloat {
            switch configuration.overscroll {
            case .automatic:
                return CTFontGetBoundingBox(font).height * 8
            case .none:
                return 0
            case .fixed(let value):
                return value
            }
        }
        textContentSize.height = max(textContentSize.height, currentPos.y) + overscroll
        logger.trace("layoutText didEnd, contentSize: \(NSStringFromSize(textContentSize))")

        // Clear invalid lines. Layout is valid
        _invalidRanges.removeAll(keepingCapacity: true)

        return textContentSize
    }

    private func createAttributedString(lineNumber: LineNumber, lineString: Substring, defaultFont: NSFont, defaultColor: CGColor) -> CFMutableAttributedString {
        let attributedString = CFAttributedStringCreateMutable(nil, 0)!
        CFAttributedStringBeginEditing(attributedString)
        CFAttributedStringReplaceString(attributedString, CFRange(), lineString as CFString)
        let attributedStringLength = CFAttributedStringGetLength(attributedString)

        // default font
        CFAttributedStringSetAttribute(attributedString, CFRange(location: 0, length: attributedStringLength), kCTFontAttributeName, defaultFont)
        // default color
        CFAttributedStringSetAttribute(attributedString, CFRange(location: 0, length: attributedStringLength), kCTForegroundColorAttributeName, defaultColor)

        // Apply attributes to NSAttibutedString used by typesetter
        // Range applies to this line
        for (range, attributes) in _textStorage._textAttributes.ranges where lineNumber >= range.start.line && lineNumber <= range.end.line {
            let cfrange: CFRange
            if lineNumber == range.start.line {
                // first line
                let rangeCharacterLength: Int
                if range.start.line == range.end.line {
                    rangeCharacterLength = range.end.character - range.start.character
                } else {
                    // slow path
                    let startCharacterIndex = _textStorage.characterIndex(at: range.start)
                    let endCharacterIndex = max(0, _textStorage.characterIndex(at: range.end) - 1) // - 1 because end is exclusive
                    rangeCharacterLength = endCharacterIndex - startCharacterIndex
                }
                cfrange = CFRange(location: range.start.character, length: max(0, min(attributedStringLength - range.start.character, rangeCharacterLength)))
            } else if lineNumber == range.end.line {
                // last line
                cfrange = CFRange(location: 0, length: max(0, min(attributedStringLength, range.end.character - 1)))
            } else {
                // in between
                cfrange = CFRange(location: 0, length: max(0, attributedStringLength))
            }

            // Apply attributes
            if let value = attributes[\String.AttributeKey.foreground] {
                let foregroundColor = value as! CGColor
                CFAttributedStringSetAttribute(attributedString, cfrange, kCTForegroundColorAttributeName, foregroundColor)
            }
        }
        CFAttributedStringEndEditing(attributedString)
        return attributedString
    }
}

