import Foundation
import Combine

/// Layout mamager uses Top-bottom, left-right coordinate system to layout lines
class LayoutManager {

    typealias LineNumber = Int

    /// Cached layout. LayoutManager datasource.
    struct LineLayout: Equatable, Hashable {
        /// Line index in store. Line number (zero based)
        /// In wrapping scenario, multiple LineLayouts for a single lineIndex.
        let lineNumber: LineNumber

        // Note: After inserting an instance of a reference type into a set, the properties of that instance must not be modified in a way that affects its hash value or testing for equality.
        //       this is why can't really use it in Set
        let ctline: CTLine
        /// A line baseline
        let baseline: CGPoint
        let bounds: CGRect
        let lineSpacing: CGFloat
        /// A string range of the line.
        /// For wrapped line its a fragment of the line.
        let stringRange: CFRange
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
    private var _invalidRanges: Set<Range>
    private var _cancellables: [AnyCancellable]

    init(configuration: Configuration, textStorage: TextStorage) {
        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(500)
        self._textStorage = textStorage
        self._invalidRanges = []
        self._cancellables = []

        self.configuration = configuration

        _cancellables.append(textStorage.storageDidChange.sink(receiveValue: invalidateLayout))
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
        _lineLayouts.filter { lineLayout in
            rect.intersects(lineLayout.bounds)
        }
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

        // TopBottom/LeftRight
        // let firstInvalidLineNumber = _invalidRanges.min()?.start.line ?? 0
        // let lastInvalidLineNumber = _invalidRanges.max()?.end.line ?? 0
        // var currentPos: CGPoint = lineLayouts(forLineNumber: firstInvalidLineNumber).first?.bounds.origin ?? .zero
        var currentPos: CGPoint = .zero

        // estimate text content size
        var textContentSize = CGSize(width: frame.width, height: CGFloat(_textStorage.linesCount) * CTFontGetBoundingBox(font).height)

        var lineLayoutsRun: [LineLayout] = []
        lineLayoutsRun.reserveCapacity(_lineLayouts.underestimatedCount)

        for lineNumber in 0..<_textStorage.linesCount {

            // WIP: re-layout invalid ranges
            if _invalidRanges.contains(where: { $0.start.line >= lineNumber && $0.end.line <= lineNumber }) {
                logger.debug("Invalid line \(lineNumber)")
            }

            // Store previous lines
            let oldLineNumberLayouts = lineLayouts(forLineNumber: lineNumber)
            var newLineNumberLayouts: [LineLayout] = []
            newLineNumberLayouts.reserveCapacity(oldLineNumberLayouts.count)

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

                newLineNumberLayouts.append(lineLayout)
                lineLayoutsRun.append(lineLayout)

                lineStartIndex += breakIndex
                currentPos.y += lineHeight + lineSpacing

                textContentSize.width = max(textContentSize.width, lineWidth)
            }

            // diff oldLineNumberLayouts -> newLineNumberLayouts
            //for change in newLineNumberLayouts.difference(from: oldLineNumberLayouts) {
            //}
            if !oldLineNumberLayouts.isEmpty && newLineNumberLayouts.count > oldLineNumberLayouts.count {
                // logger.debug("wazaaaa \(lineNumber)")
                // TODO: move everything below by height of the new line
            }

        }

        // TODO: analyze how layout change and apply changes to invisible parts below too
        // by set the Y adjustment value
        _lineLayouts = lineLayoutsRun

        textContentSize.height = max(textContentSize.height, currentPos.y)
        logger.trace("layoutText didEnd, contentSize: \(NSStringFromSize(textContentSize))")

        return textContentSize
    }
}

// MARK - Tests

#if canImport(XCTest)
import XCTest

class TextLayoytTests: XCTestCase {

    func testProvider() {

    }
}
#endif

