import Cocoa
import CoreText

// Ref: Creating Custom Views
//      https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/Tasks/TextViewTask.html#//apple_ref/doc/uid/TP40008899-BCICEFGE
//
// TODO:
//  - Text Checking: NSTextCheckingClient, NSTextCheckingController
//  - tell the input context when position information for a character range changes, when the text view scrolls, by sending the invalidateCharacterCoordinates message to the input context.
//  - Selection shouldn't move _caret.position, but _textSelection.end.position

/// Code Edit View
public final class CodeEditView: NSView {

    private typealias LineNumber = Int

    public enum LineWrapping {
        /// No wrapping
        case none
        /// Wrap at bounds
        case bounds
        /// Wrap at specific width
        case width(_ value: CGFloat = .infinity)
    }

    public enum Spacing: CGFloat {
        /// 0% line spacing
        case tight = 1.0
        /// 20% line spacing
        case normal = 1.2
        /// 40% line spacing
        case relaxed = 1.4
    }

    /// Cached layout. LayoutManager datasource.
    private struct LineLayout: Equatable {
        /// Line index in store. Line number (zero based)
        /// In wrapping scenario, multiple LineLayouts for a single lineIndex.
        let lineNumber: LineNumber
        let ctline: CTLine
        /// A point that specifies the x and y values at which line is to be drawn, in user space coordinates.
        /// A line origin based position.
        let origin: CGPoint
        let lineHeight: CGFloat
        let lineDescent: CGFloat
        /// A string range of the line.
        /// For wrapped line its a fragment of the line.
        let stringRange: CFRange

        static func == (lhs: CodeEditView.LineLayout, rhs: CodeEditView.LineLayout) -> Bool {
            return lhs.lineNumber == rhs.lineNumber &&
                lhs.ctline == rhs.ctline &&
                lhs.origin == rhs.origin &&
                lhs.lineHeight == rhs.lineHeight &&
                lhs.lineDescent == rhs.lineDescent &&
                lhs.stringRange.location == rhs.stringRange.location &&
                lhs.stringRange.length == rhs.stringRange.length
        }
    }

    private struct Caret {
        var position: Position = .zero
        var displayPosition: Position = .zero
        let view: CaretView = CaretView()

        var isHidden: Bool {
            set {
                view.isHidden = newValue
            }
            get {
                view.isHidden
            }
        }
    }

    /// Line Wrapping mode
    public var lineWrapping: LineWrapping {
        didSet {
            needsLayout = true
        }
    }

    // Whether should indent wrapped lines
    public var indentWrappedLines: Bool {
        didSet {
            needsLayout = true
        }
    }

    public var wrapWords: Bool {
        didSet {
            needsLayout = true
        }
    }

    public var highlightCurrentLine: Bool {
        didSet {
            needsDisplay = true
        }
    }

    /// Line Spacing mode
    public var lineSpacing: Spacing {
        didSet {
            needsLayout = true
        }
    }

    /// Font
    public var font: NSFont {
        didSet {
            needsLayout = true
        }
    }

    /// Text color
    public var textColor: NSColor = .textColor {
        didSet {
            needsDisplay = true
        }
    }

    /// Insert spaces when pressing Tab
    public var insertSpacesForTab: Bool {
        didSet {
            needsLayout = true
        }
    }

    /// The number of spaces a tab is equal to.
    public var tabSize: Int {
        didSet {
            needsLayout = true
        }
    }

    private var _caret: Caret {
        didSet {
            layoutCaret()
        }
    }

    private var _textSelection: SelectionRange?

    /// Whether or not this view is the focused view for its window
    private var _isFirstResponder = false {
        didSet {
            self._caret.isHidden = !_isFirstResponder
        }
    }

    private let _storage: TextStorage

    /// Cached layout
    private var _lineLayouts: [LineLayout]

    public init(storage: TextStorage) {
        self._storage = storage

        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(200)

        self.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        self.lineSpacing = .normal
        self.lineWrapping = .bounds
        self.indentWrappedLines = false
        self.wrapWords = true
        self.insertSpacesForTab = false
        self.tabSize = 4
        self.highlightCurrentLine = true

        self._caret = Caret()

        super.init(frame: .zero)

        self.addSubview(_caret.view)
        _caret.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    public override var preservesContentDuringLiveResize: Bool {
        true
    }

    public override func becomeFirstResponder() -> Bool {
        _isFirstResponder = true
        return true
    }

    public override func resignFirstResponder() -> Bool {
        _isFirstResponder = false
        return true
    }

    public override func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    public override func mouseDown(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    // MARK: - Commands

    public override func doCommand(by selector: Selector) {
        switch selector {
            case #selector(deleteBackward(_:)):
                deleteBackward(self)
            case #selector(deleteForward(_:)):
                deleteForward(self)
            case #selector(moveUp(_:)):
                moveUp(self)
            case #selector(moveUpAndModifySelection(_:)):
                moveUpAndModifySelection(self)
            case #selector(moveDown(_:)):
                moveDown(self)
            case #selector(moveDownAndModifySelection(_:)):
                moveDownAndModifySelection(self)
            case #selector(moveLeft(_:)):
                moveLeft(self)
            case #selector(moveLeftAndModifySelection(_:)):
                moveLeftAndModifySelection(self)
            case #selector(moveToLeftEndOfLine(_:)):
                moveToLeftEndOfLine(self)
            case #selector(moveToLeftEndOfLineAndModifySelection(_:)):
                moveToLeftEndOfLineAndModifySelection(self)
            case #selector(moveRight(_:)):
                moveRight(self)
            case #selector(moveRightAndModifySelection(_:)):
                moveRightAndModifySelection(self)
            case #selector(moveToRightEndOfLine(_:)):
                moveToRightEndOfLine(self)
            case #selector(moveToRightEndOfLineAndModifySelection(_:)):
                moveToRightEndOfLineAndModifySelection(self)
            case #selector(moveToBeginningOfDocument(_:)):
                moveToBeginningOfDocument(self)
            case #selector(moveToEndOfDocument(_:)):
                moveToEndOfDocument(self)
            case #selector(insertNewline(_:)):
                insertNewline(self)
            case #selector(insertLineBreak(_:)):
                insertLineBreak(self)
            case #selector(insertTab(_:)):
                insertTab(self)
            default:
                logger.debug("doCommand \(selector)")
                return
        }

        // If aSelector cannot be invoked, should not pass this message up the responder chain.
        // NSResponder also implements this method, and it does forward uninvokable commands up
        // the responder chain, but a text view should not.
        // super.doCommand(by: selector)
    }

    @objc func copy(_ sender: Any?) {
        guard let selectionRange = _textSelection?.range,
              let selectedString = _storage.string(in: selectionRange) else {
            return
        }

        updatePasteboard(with: String(selectedString))
    }

    @objc func paste(_ sender: Any?) {
        logger.debug("Paste not implemented")
    }

    @objc func cut(_ sender: Any?) {
        logger.debug("Copy not implemented")
    }

    @objc func delete(_ sender: Any?) {
        guard let selectionRange = _textSelection?.range else {
            return
        }

        if selectionRange.start > selectionRange.end {
            _storage.remove(range: selectionRange.inverted())
            _caret.position = selectionRange.end
        } else {
            _storage.remove(range: selectionRange)
            _caret.position = selectionRange.start
        }

        unselectText()
        needsLayout = true
        needsDisplay = true
    }

    public override func selectAll(_ sender: Any?) {
        let lastLineString = _storage.string(line: _storage.linesCount - 1)
        _textSelection = SelectionRange(Range(start: Position(line: 0, character: 0), end: Position(line: _storage.linesCount - 1, character: lastLineString.count - 1)))
        needsDisplay = true
    }

    public override func selectLine(_ sender: Any?) {
        _textSelection = SelectionRange(Range(start: Position(line: _caret.position.line, character: 0), end: Position(line: _caret.position.line, character: _storage.string(line: _caret.position.line).count - 1)))
        needsDisplay = true
    }

    public override func selectParagraph(_ sender: Any?) {
        // TODO
    }

    public override func selectWord(_ sender: Any?) {
        // TODO
    }

    public override func deleteBackward(_ sender: Any?) {
        defer {
            needsLayout = true
            needsDisplay = true
        }

        if _textSelection != nil {
            self.delete(sender)
            return
        }

        unselectText()

        let startingCarretPosition = _caret.position

        if _caret.position.character - 1 >= 0 {
            _caret.position = Position(line: _caret.position.line, character: _caret.position.character - 1)
            _storage.remove(range: Range(start: _caret.position, end: startingCarretPosition))
        } else {
            // move to previous line
            let lineNumber = _caret.position.line - 1
            if lineNumber >= 0 {
                let prevLineString = _storage.string(line: lineNumber)
                _caret.position = Position(line: lineNumber, character: prevLineString.count - 1)
                _storage.remove(range: Range(start: _caret.position, end: startingCarretPosition))
            }
        }
    }

    public override func deleteForward(_ sender: Any?) {
        unselectText()

        _storage.remove(range: Range(start: _caret.position, end: Position(line: _caret.position.line, character: _caret.position.character + 1)))

        needsLayout = true
        needsDisplay = true
    }

    private func caretMoveUp(_ sender: Any?) {
        let currentLineLayoutIndex = _lineLayouts.firstIndex { lineLayout -> Bool in
            _caret.position.character >= lineLayout.stringRange.location &&
                _caret.position.character < lineLayout.stringRange.location + lineLayout.stringRange.length &&
                _caret.position.line == lineLayout.lineNumber
        }

        if let idx = currentLineLayoutIndex, idx - 1 >= 0 {
            let currentLineLayout = _lineLayouts[idx]
            let prevLineLayout = _lineLayouts[idx - 1]
            let distance = min(_caret.position.character - currentLineLayout.stringRange.location, prevLineLayout.stringRange.length - 1)
            _caret.position = Position(line: prevLineLayout.lineNumber, character: prevLineLayout.stringRange.location + distance)
            scrollToVisiblePosition(_caret.position)
        }
    }

    public override func moveUp(_ sender: Any?) {
        unselectText()
        caretMoveUp(sender)
        needsDisplay = true
    }

    public override func moveUpAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveUp)
        needsDisplay = true
    }

    private func caretMoveDown(_ sender: Any?) {
        // Find lineLayout for the current caret position
        let currentLineLayoutIndex = _lineLayouts.firstIndex { lineLayout -> Bool in
            _caret.position.line == lineLayout.lineNumber &&
                _caret.position.character >= lineLayout.stringRange.location &&
                _caret.position.character < lineLayout.stringRange.location + lineLayout.stringRange.length
        }

        if let idx = currentLineLayoutIndex, idx + 1 < _lineLayouts.count {
            let currentLineLayout = _lineLayouts[idx]
            let nextLineLayout = _lineLayouts[idx + 1]
            // distance from the beginning of the current line limited by the next line lenght
            // TODO: effectively reset caret position to the beginin of the line, while it's not expected
            //       the caret offset should preserve between lines, and empty line should not reset the caret offset.
            let distance = min(_caret.position.character - currentLineLayout.stringRange.location, nextLineLayout.stringRange.length - 1)
            _caret.position = Position(line: nextLineLayout.lineNumber, character: nextLineLayout.stringRange.location + distance)
        }
    }

    public override func moveDown(_ sender: Any?) {
        unselectText()

        caretMoveDown(sender)

        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveDownAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveDown)
        needsDisplay = true
    }

    private func caretMoveLeft(_ sender: Any?) {
        if _caret.position.character > 0 {
            _caret.position = Position(line: _caret.position.line, character: max(0, _caret.position.character - 1))
        } else {
            let lineNumber = _caret.position.line - 1
            if lineNumber >= 0 {
                let prevLineString = _storage.string(line: lineNumber)
                _caret.position = Position(line: lineNumber, character: prevLineString.count - 1)
            }
        }
    }

    public override func moveLeft(_ sender: Any?) {
        defer {
            unselectText()
            needsDisplay = true
        }

        if let selectionRange = _textSelection?.range {
            if selectionRange.start > selectionRange.end {
                _caret.position = selectionRange.end
            } else {
                _caret.position = selectionRange.start
            }
            return
        }

        caretMoveLeft(sender)
    }

    public override func moveLeftAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveLeft)
        needsDisplay = true
    }

    public override func moveToLeftEndOfLine(_ sender: Any?) {
        unselectText()
        _caret.position = Position(line: _caret.position.line, character: 0)
        needsDisplay = true
    }

    public override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection { sender in
            _caret.position = Position(line: _caret.position.line, character: 0)
        }
        needsDisplay = true
    }

    private func caretMoveRight(_ sender: Any?) {
        let currentLineString = _storage.string(line: _caret.position.line)
        if _caret.position.character + 1 < currentLineString.count {
            _caret.position = Position(line: _caret.position.line, character: _caret.position.character + 1)
        } else {
            moveDown(sender)
        }
    }

    public override func moveRight(_ sender: Any?) {
        defer {
            unselectText()
            needsDisplay = true
        }

        if let selectionRange = _textSelection?.range {

            if selectionRange.start > selectionRange.end {
                _caret.position = selectionRange.start
            } else {
                _caret.position = selectionRange.end
            }

            return
        }

        caretMoveRight(sender)
    }

    public override func moveRightAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveRight)
        needsDisplay = true
    }

    public override func moveToRightEndOfLine(_ sender: Any?) {
        unselectText()

        _caret.position = Position(line: _caret.position.line, character: _storage.string(line: _caret.position.line).count - 1)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection { sender in
            _caret.position = Position(line: _caret.position.line, character: _storage.string(line: _caret.position.line).count - 1)
        }
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToBeginningOfDocument(_ sender: Any?) {
        unselectText()

        _caret.position = Position(line: 0, character: 0)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToEndOfDocument(_ sender: Any?) {
        unselectText()

        let lastLineString = _storage.string(line: _storage.linesCount - 1)
        _caret.position = Position(line: _storage.linesCount - 1, character: lastLineString.count - 1)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func insertNewline(_ sender: Any?) {
        unselectText()

        _storage.insert(string: "\n", at: _caret.position)
        _caret.position = Position(line: _caret.position.line + 1, character: 0)

        needsLayout = true
        needsDisplay = true

        scrollToVisiblePosition(_caret.position)
    }

    public override func insertLineBreak(_ sender: Any?) {
        unselectText()
        insertNewline(sender)
    }

    public override func insertTab(_ sender: Any?) {
        if insertSpacesForTab {
            self.insertText(String([Character](repeating: " ", count: tabSize)), replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            self.insertText("\t", replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        scrollToVisiblePosition(_caret.position)
    }

    private func moveCaretAndModifySelection(_ moveCaret: (_ sender: Any?) -> Void) {
        let beforeMoveCaretPosition = _caret.position
        moveCaret(nil)
        let afterMoveCaretPosition = _caret.position

        if let currentSelectionRange = _textSelection?.range {
            _textSelection = SelectionRange(Range(start: currentSelectionRange.start, end: afterMoveCaretPosition))
        } else {
            _textSelection = SelectionRange(Range(start: beforeMoveCaretPosition, end: afterMoveCaretPosition))
        }

        logger.debug("\(self._textSelection!.range)")
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        if _isFirstResponder && highlightCurrentLine {
            drawHighlightedLine(context, dirtyRect: dirtyRect)
        }

        drawSelection(context, dirtyRect: dirtyRect)
        drawLines(context, dirtyRect: dirtyRect)
    }

    public override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
    }

    private func drawLines(_ context: CGContext, dirtyRect: NSRect) {
        context.saveGState()
        context.setFillColor(textColor.cgColor)

        // draw text lines
        let overscanDirtyRect = dirtyRect.insetBy(dx: -font.boundingRectForFont.width * 4, dy: -font.boundingRectForFont.height * 4)
        for lineLayout in _lineLayouts where lineLayout.origin.y >= overscanDirtyRect.minY && lineLayout.origin.y <= overscanDirtyRect.maxY {
            context.textPosition = CGPoint(x: lineLayout.origin.x, y: lineLayout.origin.y)
            CTLineDraw(lineLayout.ctline, context)
        }
        context.restoreGState()
    }

    private func drawHighlightedLine(_ context: CGContext, dirtyRect: NSRect) {
        // Find lineLayout for the current caret position
        let currentLineLayoutIndex = _lineLayouts.firstIndex { lineLayout -> Bool in
            _caret.position.line == lineLayout.lineNumber &&
                _caret.position.character >= lineLayout.stringRange.location &&
                _caret.position.character < lineLayout.stringRange.location + lineLayout.stringRange.length
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }

        if let idx = currentLineLayoutIndex {
            let lineLayout = _lineLayouts[idx]
            let lineRect = CGRect(x: frame.minX,
                                  y: lineLayout.origin.y - lineLayout.lineDescent - 1.5, // 1.5 should be calculated
                                  width: frame.width,
                                  height: lineLayout.lineHeight)

            context.saveGState()
            let color = NSColor.controlAccentColor.withAlphaComponent(0.1)
            context.setFillColor(color.cgColor)
            context.fill(lineRect)
        }
    }

    private func drawSelection(_ context: CGContext, dirtyRect: NSRect) {
        guard let selectionRange = _textSelection?.range else {
            return
        }

        logger.debug("drawSelection \(selectionRange)")

        context.saveGState()
        defer {
            context.restoreGState()
        }

        context.setFillColor(NSColor.selectedTextBackgroundColor.cgColor)

        guard let startSelectedLineLayout = self.lineLayout(for: selectionRange.start),
           let endSelectedLineLayout = self.lineLayout(for: selectionRange.end),
           let startSelectedLineIndex = _lineLayouts.firstIndex(of: startSelectedLineLayout),
           let endSelectedLineIndex = _lineLayouts.firstIndex(of: endSelectedLineLayout) else
        {
            assertionFailure("update layout and attempt to redraw")
            return
        }

        if startSelectedLineIndex <= endSelectedLineIndex {
            for lineIndex in startSelectedLineIndex...endSelectedLineIndex {
                let currentLineLayout = _lineLayouts[lineIndex]

                let startPositionX: CGFloat
                let rectWidth: CGFloat

                if lineIndex == startSelectedLineIndex {
                    // start - partial selection
                    let startCharacterPositionOffset = CTLineGetOffsetForStringIndex(currentLineLayout.ctline, selectionRange.start.character, nil)
                    let endPositionOffset = CTLineGetOffsetForStringIndex(startSelectedLineLayout.ctline, selectionRange.end.character, nil)
                    startPositionX = currentLineLayout.origin.x + startCharacterPositionOffset

                    if startSelectedLineLayout != endSelectedLineLayout {
                        // selection that ends on another line ends at the end of the view
                        // not at the end of the line
                        rectWidth = frame.width - currentLineLayout.origin.x
                    } else {
                        rectWidth = endPositionOffset - startCharacterPositionOffset
                    }
                } else if lineIndex == endSelectedLineIndex {
                    // end - partial selection
                    let endCharacterPositionOffset = CTLineGetOffsetForStringIndex(currentLineLayout.ctline, selectionRange.end.character, nil)
                    startPositionX = 0
                    rectWidth = endCharacterPositionOffset + currentLineLayout.origin.x
                } else {
                    // x + 1..<y full line selection
                    startPositionX = frame.minX // currentLineLayout.origin.x
                    rectWidth = frame.width
                }

                context.fill(CGRect(x: startPositionX,
                                    y: currentLineLayout.origin.y - currentLineLayout.lineDescent - 1.5, // 1.5 should be calculated
                                    width: rectWidth,
                                    height: currentLineLayout.lineHeight))
            }
        }

        if startSelectedLineIndex > endSelectedLineIndex {
            for lineIndex in endSelectedLineIndex...startSelectedLineIndex {
                let currentLineLayout = _lineLayouts[lineIndex]

                let startPositionX: CGFloat
                let rectWidth: CGFloat

                if lineIndex == startSelectedLineIndex {
                    // start - partial selection from the beginning to the start selection
                    let startCharacterPositionOffset = CTLineGetOffsetForStringIndex(currentLineLayout.ctline, selectionRange.start.character, nil)
                    startPositionX = 0
                    rectWidth = startCharacterPositionOffset + currentLineLayout.origin.x
                } else if lineIndex == endSelectedLineIndex {
                    // end - partial selection from the end to the end of the line
                    let endCharacterPositionOffset = CTLineGetOffsetForStringIndex(currentLineLayout.ctline, selectionRange.end.character, nil)
                    let startPositionOffset = CTLineGetOffsetForStringIndex(startSelectedLineLayout.ctline, selectionRange.start.character, nil)
                    startPositionX = currentLineLayout.origin.x + endCharacterPositionOffset

                    if startSelectedLineLayout != endSelectedLineLayout {
                        // selection that ends on another line ends at the end of the view
                        // not at the end of the line
                        rectWidth = frame.width - currentLineLayout.origin.x
                    } else {
                        rectWidth = startPositionOffset - endCharacterPositionOffset
                    }
                } else {
                    // x + 1..<y full line selection
                    startPositionX = frame.minX // currentLineLayout.origin.x
                    rectWidth = frame.width
                }

                context.fill(CGRect(x: startPositionX,
                                    y: currentLineLayout.origin.y - currentLineLayout.lineDescent - 1.5, // 1.5 should be calculated
                                    width: rectWidth,
                                    height: currentLineLayout.lineHeight))
            }
        }
    }

    public override func layout() {
        super.layout()
        layoutText()
        layoutCaret()
    }

    private func layoutCaret() {
        guard let lineLayout = lineLayout(for: _caret.position) else { return }
        let positionOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, _caret.position.character, nil)
        _caret.view.frame = CGRect(x: lineLayout.origin.x + positionOffset,
                                   y: lineLayout.origin.y - lineLayout.lineDescent,
                                   width: font.boundingRectForFont.width,
                                   height: lineLayout.lineHeight - lineLayout.lineDescent)
    }

    /// Layout visible text
    private func layoutText() {
        logger.trace("layoutText willStart")
        // os_log(.debug, "layoutText")

        // Let's layout some text. Top Bottom/Left Right
        // TODO: update layout
        // 1. find text range for displayed dirtyRect
        // 2. draw text from the range
        // 3. Layout only lines that meant to be displayed +- overscan

        // Largest content size needed to draw the lines
        var textContentSize = CGSize()

        let lineBreakWidth: CGFloat
        switch lineWrapping {
            case .none:
                lineBreakWidth = CGFloat.infinity
            case .bounds:
                lineBreakWidth = frame.width
            case .width(let width):
                lineBreakWidth = width
        }

        _lineLayouts.removeAll(keepingCapacity: true)

        // Top Bottom/Left Right
        var pos = CGPoint.zero

        for lineIndex in 0..<_storage.linesCount {
            let lineString = _storage.string(line: lineIndex)

            let attributedString = CFAttributedStringCreate(nil, lineString as CFString, [
                kCTFontAttributeName: font,
                kCTForegroundColorFromContextAttributeName: NSNumber(booleanLiteral: true)
            ] as CFDictionary)!
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)

            let indentWidth = indentWrappedLines ? font.pointSize : 0

            var isWrappedLine = false
            var lineStartIndex: CFIndex = 0
            while lineStartIndex < lineString.count {
                if lineStartIndex > 0 {
                    isWrappedLine = true
                }

                let leadingIndent = isWrappedLine ? indentWidth : 0
                pos.x = leadingIndent

                let breakIndex: CFIndex
                if wrapWords {
                    breakIndex = CTTypesetterSuggestLineBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - leadingIndent), Double(pos.y))
                } else {
                    breakIndex = CTTypesetterSuggestClusterBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth - leadingIndent), Double(pos.y))
                }
                let stringRange = CFRange(location: lineStartIndex, length: breakIndex)

                // Bottleneck
                let ctline = CTTypesetterCreateLineWithOffset(typesetter, stringRange, Double(pos.x))

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading)) + leadingIndent
                let lineHeight = (ascent + descent + leading) * lineSpacing.rawValue

                // font origin based position
                _lineLayouts.append(
                    LineLayout(lineNumber: lineIndex,
                               ctline: ctline,
                               origin: CGPoint(x: pos.x, y: pos.y + (ascent + descent)),
                               lineHeight: lineHeight,
                               lineDescent: descent,
                               stringRange: stringRange)
                )

                lineStartIndex += breakIndex
                pos.y += lineHeight

                textContentSize.width = max(textContentSize.width, lineWidth)
            }
        }
        textContentSize.height = pos.y

        // Adjust Width
        if lineBreakWidth != frame.size.width {
            frame.size.width = textContentSize.width
        }

        // Adjust Height
        let prevContentOffset = enclosingScrollView?.documentVisibleRect.origin ?? .zero
        let prevFrame = frame

        // Update ContentSize
        frame.size.height = (1000 * max(textContentSize.height, visibleRect.height).rounded()) / 1000

        // Preserve content offset
        let heightDelta = frame.size.height - prevFrame.size.height
        scroll(CGPoint(x: prevContentOffset.x, y: prevContentOffset.y + heightDelta))

        // Flip Y. Performance killer
        _lineLayouts = _lineLayouts.map { lineLayout -> LineLayout in
            LineLayout(lineNumber: lineLayout.lineNumber,
                       ctline: lineLayout.ctline,
                       origin: CGPoint(x: lineLayout.origin.x, y: frame.height - lineLayout.origin.y),
                       lineHeight: lineLayout.lineHeight,
                       lineDescent: lineLayout.lineDescent,
                       stringRange: lineLayout.stringRange)
        }
        logger.trace("layoutText didEnd")
    }

    // MARK: - Helpers

    private func updatePasteboard(with text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSPasteboardWriting])
    }

    private func unselectText() {
        _textSelection = nil
    }

    private func lineLayout(for position: Position) -> LineLayout? {
        _lineLayouts.first {
            position.line == $0.lineNumber &&
                position.character >= $0.stringRange.location && position.character < $0.stringRange.location + $0.stringRange.length
        }
    }

    private func scrollToVisiblePosition(_ position: Position) {
        guard let lineLayout = lineLayout(for: position) else {
            return
        }
        scrollToVisibleLineLayout(lineLayout)
    }

    private func scrollToVisibleLineLayout(_ lineLayout: LineLayout) {
        scrollToVisible(CGRect(x: 0,
                               y: lineLayout.origin.y - lineLayout.lineDescent,
                               width: frame.width,
                               height: lineLayout.lineHeight + lineLayout.lineDescent))
    }
}

// The default implementation of the NSView method inputContext manages
// an NSTextInputContext instance automatically if the view subclass conforms
// to the NSTextInputClient protocol.
extension CodeEditView: NSTextInputClient {

    public func insertText(_ string: Any, replacementRange: NSRange) {
        guard let string = string as? String else {
            return
        }

        guard !string.unicodeScalars.contains(where: { $0.properties.isDefaultIgnorableCodePoint || $0.properties.isNoncharacterCodePoint }) else {
            logger.info("Ignore bytes: \(Array(string.utf8))")
            return
        }

        // Ignore ASCII control characters
        if string.count == 1 && string.unicodeScalars.drop(while: { (0x10...0x1F).contains($0.value) }).isEmpty {
            logger.info("Ignore control characters 0x10...0x1F")
            return
        }

        unselectText()

        logger.debug("insertText \(string) replacementRange \(replacementRange)")
        _storage.insert(string: string, at: _caret.position)

        // if string contains new line, caret position need to adjust
        let newLineCount = string.reduce(0, { $1.isNewline ? $0 + 1 : $0 })
        _caret.position = Position(
            line: _caret.position.line + newLineCount,
            // FIXME: position depends on the last added line
            character: _caret.position.character + string.count
        )

        needsLayout = true
        needsDisplay = true
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        logger.debug("setMarkedText \(string as! String) selectedRange \(selectedRange) replacementRange \(replacementRange)")
    }

    public func unmarkText() {
        logger.debug("unmarkText")
    }

    public func selectedRange() -> NSRange {
        logger.debug("selectedRange")

        guard let selectionRange = _textSelection?.range else {
            return NSRange(location: NSNotFound, length: 0)
        }

        // _selectionRange -> NSRange
        let startIndex = _storage.positionOffset(at: selectionRange.start)
        let endIndex = _storage.positionOffset(at: selectionRange.end)

        return NSRange(location: startIndex, length: endIndex - startIndex)
    }

    public func markedRange() -> NSRange {
        logger.debug("markedRange")
        return NSRange(location: NSNotFound, length: 0)
    }

    public func hasMarkedText() -> Bool {
        logger.debug("hasMarkedText")
        return false
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        logger.debug("attributedSubstring forProposedRange \(range)")
        return NSAttributedString()
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [.font, .backgroundColor, .foregroundColor]
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        logger.debug("firstRect forCharacterRange \(range)")
        return NSRect.zero
    }

    public func characterIndex(for point: NSPoint) -> Int {
        logger.debug("characterIndex \(point.debugDescription)")
        return NSNotFound
        //return 0
    }
}
