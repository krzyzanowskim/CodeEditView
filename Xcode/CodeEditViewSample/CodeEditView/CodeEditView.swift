import Cocoa
import CoreText

// Ref: Creating Custom Views
//      https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/Tasks/TextViewTask.html#//apple_ref/doc/uid/TP40008899-BCICEFGE
//
// TODO:
//  - Text Checking: NSTextCheckingClient, NSTextCheckingController
//  - tell the input context when position information for a character range changes, when the text view scrolls, by sending the invalidateCharacterCoordinates message to the input context.

/// Code Edit View
public final class CodeEditView: NSView {

    private typealias LineNumber = Int

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

    public var showWrappingLine: Bool {
        didSet {
            needsDisplay = true
        }
    }

    public var highlightCurrentLine: Bool {
        didSet {
            needsDisplay = true
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
    private let _layoutManager: LayoutManager

    /// Cached layout
    //private var _lineLayouts: [LineLayout]

    public init(storage: TextStorage) {
        self._storage = storage
        self._layoutManager = LayoutManager()

        self.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        self.showWrappingLine = true
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

    public override var isFlipped: Bool {
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

    public override func yank(_ sender: Any?) {
        self.copy(sender)
    }

    @objc func copy(_ sender: Any?) {
        guard let selectionRange = _textSelection?.range else {
            return
        }

        let selectedString: String
        if selectionRange.start < selectionRange.end {
            selectedString = String(_storage.string(in: selectionRange)!)
        } else {
            selectedString = String(_storage.string(in: selectionRange.inverted())!)
        }

        updatePasteboard(with: selectedString)
    }

    @objc func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string) else {
            return
        }

        self.insertText(string)
    }

    @objc func cut(_ sender: Any?) {
        self.copy(sender)
        self.delete(sender)
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

    public override func uppercaseWord(_ sender: Any?) {
        // TODO: uppercaseWord
    }

    public override func lowercaseWord(_ sender: Any?) {
        // TODO: lowercaseWord
    }

    public override func capitalizeWord(_ sender: Any?) {
        // TODO: capitalizeWord
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
        // TODO: selectParagraph
    }

    public override func selectWord(_ sender: Any?) {
        // TODO: selectWord
    }

    public override func insertText(_ insertString: Any) {
        guard let string = insertString as? String else {
            return
        }
        self.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
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
        guard let currentLineLayout = _layoutManager.lineLayout(at: _caret.position),
              let prevLineLayout = _layoutManager.lineLayout(before: currentLineLayout) else {
            return
        }

        // distance from the beginning of the current line limited by the next line length
        // TODO: effectively reset caret position to the beginin of the line, while it's not expected
        //       the caret offset should preserve between lines, and empty line should not reset the caret offset.
        let distance = min(_caret.position.character - currentLineLayout.stringRange.location, prevLineLayout.stringRange.length - 1)
        _caret.position = Position(line: prevLineLayout.lineNumber, character: prevLineLayout.stringRange.location + distance)
    }

    public override func moveUp(_ sender: Any?) {
        unselectText()
        caretMoveUp(sender)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveUpAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveUp)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    private func caretMoveDown(_ sender: Any?) {
        guard let currentLineLayout = _layoutManager.lineLayout(at: _caret.position),
              let nextLineLayout = _layoutManager.lineLayout(after: currentLineLayout) else {
            return
        }

        // distance from the beginning of the current line limited by the next line length
        // TODO: effectively reset caret position to the beginin of the line, while it's not expected
        //       the caret offset should preserve between lines, and empty line should not reset the caret offset.
        let distance = min(_caret.position.character - currentLineLayout.stringRange.location, nextLineLayout.stringRange.length - 1)
        _caret.position = Position(line: nextLineLayout.lineNumber, character: nextLineLayout.stringRange.location + distance)
    }

    public override func moveDown(_ sender: Any?) {
        unselectText()
        caretMoveDown(sender)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveDownAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection(caretMoveDown)
        scrollToVisiblePosition(_caret.position)
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
            scrollToVisiblePosition(_caret.position)
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
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToLeftEndOfLine(_ sender: Any?) {
        unselectText()
        _caret.position = Position(line: _caret.position.line, character: 0)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        moveCaretAndModifySelection { sender in
            _caret.position = Position(line: _caret.position.line, character: 0)
        }
        scrollToVisiblePosition(_caret.position)
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
            scrollToVisiblePosition(_caret.position)
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
        scrollToVisiblePosition(_caret.position)
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
        scrollToVisiblePosition(_caret.position)
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
        drawText(context, dirtyRect: dirtyRect)
        drawWrappingLine(context, dirtyRect: dirtyRect)
    }

    public override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
    }

    private func drawWrappingLine(_ context: CGContext, dirtyRect: NSRect) {
        guard showWrappingLine, case .width(let wrapWidth) = _layoutManager.configuration.lineWrapping else {
            return
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }

        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.move(to: CGPoint(x: wrapWidth, y: dirtyRect.minY))
        context.addLine(to: CGPoint(x: wrapWidth, y: dirtyRect.maxY))
        context.strokePath()
    }

    private func drawText(_ context: CGContext, dirtyRect: NSRect) {
        context.saveGState()
        defer {
            context.restoreGState()
        }

        context.textMatrix = CGAffineTransform(scaleX: 1, y: isFlipped ? -1 : 1)
        context.setFillColor(textColor.cgColor)

        // Draw text lines for bigger area to avoid frictions.
        let overscanDirtyRect = dirtyRect.insetBy(dx: -font.boundingRectForFont.width * 4, dy: -font.boundingRectForFont.height * 4)

        for lineLayout in _layoutManager.linesLayout(in: overscanDirtyRect) {
            context.textPosition = CGPoint(x: lineLayout.origin.x, y: lineLayout.origin.y)
            CTLineDraw(lineLayout.ctline, context)
        }
    }

    private func drawHighlightedLine(_ context: CGContext, dirtyRect: NSRect) {
        guard let caretBounds = _layoutManager.caretBounds(at: _caret.position) else {
            return
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }

        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor)

        let lineRect = CGRect(x: frame.minX,
                              y: caretBounds.origin.y,
                              width: frame.width,
                              height: caretBounds.height)

        context.fill(lineRect)
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

        guard let startSelectedLineLayout = _layoutManager.lineLayout(at: selectionRange.start),
           let endSelectedLineLayout = _layoutManager.lineLayout(at: selectionRange.end),
           let startSelectedLineIndex = _layoutManager.lineLayoutIndex(startSelectedLineLayout),
           let endSelectedLineIndex = _layoutManager.lineLayoutIndex(endSelectedLineLayout) else
        {
            assertionFailure("update layout and attempt to redraw")
            return
        }

        if startSelectedLineIndex <= endSelectedLineIndex {
            for lineIndex in startSelectedLineIndex...endSelectedLineIndex {
                guard let currentLineLayout = _layoutManager.lineLayout(idx: lineIndex) else {
                    continue
                }

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

                let currentLineBounds = _layoutManager.bounds(lineLayout: currentLineLayout)
                context.fill(CGRect(x: startPositionX,
                                    y: currentLineBounds.origin.y,
                                    width: rectWidth,
                                    height: currentLineBounds.height))
            }
        }

        if startSelectedLineIndex > endSelectedLineIndex {
            for lineIndex in endSelectedLineIndex...startSelectedLineIndex {
                guard let currentLineLayout = _layoutManager.lineLayout(idx: lineIndex) else {
                    continue
                }

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

                let currentLineBounds = _layoutManager.bounds(lineLayout: currentLineLayout)
                context.fill(CGRect(x: startPositionX,
                                    y: currentLineBounds.origin.y,
                                    width: rectWidth,
                                    height: currentLineBounds.height))
            }
        }
    }

    public override func layout() {
        super.layout()
        layoutText()
        layoutCaret()
    }

    private func layoutCaret() {
        guard let caretBounds = _layoutManager.caretBounds(at: _caret.position) else {
            return
        }
        _caret.view.frame = caretBounds
    }

    /// Layout visible text
    private func layoutText() {
        let textContentSize = _layoutManager.layoutText(storage: _storage, font: font, frame: visibleRect)
        if frame.size != textContentSize {
            frame.size = textContentSize
        }
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

    private func scrollToVisiblePosition(_ position: Position) {
        guard let caretBounds = _layoutManager.caretBounds(at: position) else {
            return
        }

        scrollToVisible(caretBounds)
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

        scrollToVisiblePosition(_caret.position)
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
