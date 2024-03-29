import Cocoa
import CoreText

// Ref: Creating Custom Views
//      https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/Tasks/TextViewTask.html#//apple_ref/doc/uid/TP40008899-BCICEFGE
//
// TODO:
//  - Text Checking: NSTextCheckingClient, NSTextCheckingController
//  - tell the input context when position information for a character range changes, when the text view scrolls, by sending the invalidateCharacterCoordinates message to the input context.
//  - Remember maxX of caret and back to the position if there's enough characters in new line
//  - Undo text attributes along text

/// Code Edit View
public final class CodeEditView: NSView {

    private struct Caret {
        var position: Position = .zero
        var isAvailable: Bool = false
    }

    private var _caretBlinkTimer: BlinkTimer = BlinkTimer()
    private var _caret: Caret = Caret() {
        didSet {
            _caretBlinkTimer.suspend()

            needsDisplay = true

            // resume after a while
            _caretBlinkTimer.resume()

            // TODO: Move the logic to LayoutManager to maintain last max X caret position
            //_caretPreferedX = max(_layoutManager.caretBounds(at: _caret.position)?.minX ?? 0, _caretPreferedX ?? 0)
            //
            //guard let currentLineCaretBounds = _layoutManager.caretBounds(at: oldValue.position),
            //      let newLineLayout = _layoutManager.lineLayout(at: _caret.position),
            //      let newCaretPosition = _layoutManager.position(at: CGPoint(x: max(currentLineCaretBounds.origin.x, _caretPreferedX ?? 0), y: newLineLayout.bounds.origin.y + 10))
            //else {
            //    return
            //}
            //_caret.position = newCaretPosition
        }
    }
    // private var _caretPreferedX: CGFloat? // TODO: Move this logic to LayoutManager

    /// Current text selection. Single selection range.
    private var _textSelection: SelectionRange? {
        didSet {
            _caret.isAvailable = _isFirstResponder && (_textSelection == nil || (_textSelection != nil && _textSelection!.isEmpty))
        }
    }

    #warning("Needs more work. the range is never set.")
    /// NSTextInputClient marked text range.
    private var _markedRange: NSRange = NSRange(location: NSNotFound, length: 0)

    /// Whether or not this view is the focused view for its window
    private var _isFirstResponder = false {
        didSet {
            _caret.isAvailable = _isFirstResponder
            needsDisplay = true
        }
    }

    private var _trackingArea: NSTrackingArea?

    public struct Configuration {
        /// Whether the text view allow the user to edit text.
        public var isEditable: Bool = true
        /// Line wrapping mode.
        public var lineWrapping: LineWrapping = .bounds
        /// Show wrapping line
        public var showWrappingLine: Bool = false
        /// Wrap on words.
        public var wrapWords: Bool = true
        /// Indent wrapped lines.
        public var indentWrappedLines: Bool = true
        /// Indentation level.
        public var indentLevel: Int = 2
        /// Line spacing style.
        public var lineSpacing: LineSpacing = .normal

        /// Default font
        public var font: NSFont = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        /// Text color
        public var textColor: NSColor = .textColor
        /// Highlight current (caret) line
        public var highlightCurrentLine: Bool = true
        /// The number of spaces a tab is equal to.
        public var tabSpaceSize: Int = 4
        /// Insert spaces when pressing Tab
        public var insertSpacesForTab: Bool = true

        public static let `default` = Configuration()
    }

    public var configuration: Configuration = .default {
        didSet {
            needsLayout = true
            needsDisplay = true
        }
    }

    private let _textStorage: TextStorage
    let _layoutManager: LayoutManager

    public init(storage: TextStorage, configuration: Configuration = .default) {
        self._textStorage = storage

        self._layoutManager = LayoutManager(configuration: .init(lineWrapping: configuration.lineWrapping,
                                                                 wrapWords: configuration.wrapWords,
                                                                 indentWrappedLines: configuration.indentWrappedLines,
                                                                 indentLevel: configuration.indentLevel,
                                                                 lineSpacing: configuration.lineSpacing),
                                            textStorage: _textStorage)
        self.configuration = configuration

        super.init(frame: .zero)
        self.canDrawConcurrently = true
        setupCaretBlinkTimer()
    }

    required init?(coder: NSCoder) {
        self._textStorage = TextStorage()
        self._layoutManager = LayoutManager(configuration: .init(lineWrapping: configuration.lineWrapping,
                                                                 wrapWords: configuration.wrapWords,
                                                                 indentWrappedLines: configuration.indentWrappedLines,
                                                                 indentLevel: configuration.indentLevel,
                                                                 lineSpacing: configuration.lineSpacing),
                                            textStorage: _textStorage)

        super.init(coder: coder)
        self.canDrawConcurrently = true
        setupCaretBlinkTimer()
    }

    private func setupCaretBlinkTimer() {
        _caretBlinkTimer.setEventHandler { [unowned self] _ in
            if _caret.isAvailable, let caretBounds = _layoutManager.caretBounds(at: _caret.position) {
                setNeedsDisplay(caretBounds)
            }
        }
        _caretBlinkTimer.resume()
    }

    public override var acceptsFirstResponder: Bool {
        configuration.isEditable
    }

    public override var preservesContentDuringLiveResize: Bool {
        true
    }

    public override var isFlipped: Bool {
        true
    }

    public override var wantsDefaultClipping: Bool {
        false
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

    public override func updateTrackingAreas() {
        if let trackingArea = _trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(rect: frame,
                                          options: [.activeWhenFirstResponder, .inVisibleRect, .cursorUpdate],
                                          owner: self,
                                          userInfo: nil)

        self.addTrackingArea(trackingArea)
        _trackingArea = trackingArea
    }

    public override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.iBeam.set()
    }

    public override func mouseDown(with event: NSEvent) {
        defer {
            super.mouseDown(with: event)
        }

        if let inputContext = inputContext, inputContext.handleEvent(event) {
            return
        }

        let mouseDownLocation = convert(event.locationInWindow, from: nil)
        guard let mouseDownPosition = _layoutManager.position(at: mouseDownLocation) else {
            return
        }

        if event.modifierFlags.contains(.shift) {
            // extend selection
            _textSelection = SelectionRange(Range(start: _textSelection?.range.start ?? _caret.position, end: mouseDownPosition))
            needsDisplay = true
        } else {
            // move caret
            unselectText()
            _caret.position = mouseDownPosition
        }

        // Drag selection
        var keepOn = true
        while keepOn {
            guard let theEvent = self.window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else {
                continue
            }

            switch theEvent.type {
                case .leftMouseDragged:
                    // extend selection
                    let dragLocation = convert(theEvent.locationInWindow, from: nil)
                    guard let dragPosition = _layoutManager.position(at: dragLocation) else {
                        continue
                    }
                    let newSelection = SelectionRange(Range(start: _textSelection?.range.start ?? _caret.position, end: dragPosition))
                    if !newSelection.isEmpty {
                        _textSelection = newSelection
                        needsDisplay = true
                    } else {
                        _textSelection = nil
                    }
                case .leftMouseUp:
                    keepOn = false
                default:
                    break
            }
        }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let mouseDownLocation = convert(event.locationInWindow, from: nil)
        guard let mouseDownPosition = _layoutManager.position(at: mouseDownLocation) else {
            return nil
        }
        _caret.position = mouseDownPosition

        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "").keyEquivalentModifierMask = [.command]
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "").keyEquivalentModifierMask = [.command]
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "").keyEquivalentModifierMask = [.command]
        return menu
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

//        var rects: UnsafePointer<NSRect>?
//        var count = Int()
//
//        getRectsBeingDrawn(&rects, count: &count)
//        print(count)
//        for i in 0..<count {
//            print(rects![i])
//        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        if _isFirstResponder && configuration.highlightCurrentLine {
            if _textSelection == nil {
                drawHighlightedLine(context, dirtyRect: dirtyRect)
            }
        }

        if _textSelection != nil {
            drawSelection(context, dirtyRect: dirtyRect)
        }

        drawText(context, dirtyRect: dirtyRect)

        if configuration.showWrappingLine {
            drawWrappingLine(context, dirtyRect: dirtyRect)
        }

        drawCaret(context, dirtyRect: dirtyRect)
    }

    public override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
    }

    private func drawWrappingLine(_ context: CGContext, dirtyRect: NSRect) {
        guard case .width(let wrapWidth) = _layoutManager.configuration.lineWrapping else {
            return
        }

        context.saveGState()

        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.move(to: CGPoint(x: wrapWidth, y: dirtyRect.minY))
        context.addLine(to: CGPoint(x: wrapWidth, y: dirtyRect.maxY))
        context.strokePath()

        context.restoreGState()
    }

    private func drawCaret(_ context: CGContext, dirtyRect: NSRect) {
        guard _caret.isAvailable && _caretBlinkTimer.caretIsVisible else {
            return
        }

        guard let caretBounds = _layoutManager.caretBounds(at: _caret.position),
              caretBounds.intersects(dirtyRect) else
        {
            return
        }

        context.saveGState()

        context.setFillColor(configuration.textColor.cgColor)
        var caretRect = caretBounds
        caretRect.size.width = 1
        context.addRect(caretRect)
        context.fillPath()

        context.restoreGState()
    }

    private func drawText(_ context: CGContext, dirtyRect: NSRect) {
        context.saveGState()

        context.textMatrix = CGAffineTransform(scaleX: 1, y: isFlipped ? -1 : 1)

        // Draw text lines for bigger area to avoid frictions.
        let boundingRectForFont = configuration.font.boundingRectForFont
        let overscanDirtyRect = dirtyRect.insetBy(dx: -boundingRectForFont.width * 4, dy: -boundingRectForFont.height * 4)

        for lineLayout in _layoutManager.linesLayouts(in: overscanDirtyRect) {
            context.textPosition = lineLayout.bounds.offsetBy(dx: 0, dy: lineLayout.baseline.y).origin

            // CRLineDraw is enough for now, but for more sophisticated attributes
            // We may need to use CTRun. But only if it's needed.
            CTLineDraw(lineLayout.ctline, context)

            //for run in CTLineGetGlyphRuns(lineLayout.ctline) as? [CTRun] ?? [] {
            //    guard let glyphsPtr = CTRunGetGlyphsPtr(run), let positionsPtr = CTRunGetPositionsPtr(run) else {
            //        continue
            //    }
            //
            //    guard let attributes = CTRunGetAttributes(run) as? [CFString: Any] else {
            //        continue
            //    }
            //
            //    context.saveGState()
            //
            //    if let attribute = attributes[kCTForegroundColorAttributeName] {
            //        let foregroundColor = attribute as! CGColor
            //        context.setFillColor(foregroundColor)
            //    }
            //
            //    CTFontDrawGlyphs(configuration.font, glyphsPtr, positionsPtr, CTRunGetGlyphCount(run), context)
            //
            //    context.restoreGState()
            //}
        }

        context.restoreGState()
    }

    private func drawHighlightedLine(_ context: CGContext, dirtyRect: NSRect) {
        guard let lineLayout = _layoutManager.lineLayout(at: _caret.position) else {
            return
        }

        // This is a noble idea, but won't work here.
        // It is possible that the other drawing pass (different rect). will overdraw this region with a background.
        // guard lineLayout.bounds.intersects(dirtyRect) else {
        //    return
        // }

        context.saveGState()
        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor)
        context.setShouldAntialias(false)

        let lineRect = CGRect(x: frame.origin.x,
                              y: lineLayout.bounds.origin.y,
                              width: frame.width,
                              height: lineLayout.bounds.height).insetBy(dx: 0, dy: -lineLayout.lineSpacing / 2)

        context.fill(lineRect)
        context.restoreGState()
    }

    private func drawSelection(_ context: CGContext, dirtyRect: NSRect) {
        guard let selectionRange = _textSelection?.range else {
            return
        }

        guard let startSelectedLineLayout = _layoutManager.lineLayout(at: selectionRange.start),
           let endSelectedLineLayout = _layoutManager.lineLayout(at: selectionRange.end),
           let startSelectedLineIndex = _layoutManager.lineLayoutIndex(startSelectedLineLayout),
           let endSelectedLineIndex = _layoutManager.lineLayoutIndex(endSelectedLineLayout) else
        {
            assertionFailure("update layout and attempt to redraw")
            return
        }

        // This is a noble idea, but won't work here.
        // It is possible that the other drawing pass (different rect). will overdraw this region with a background.
        // guard startSelectedLineLayout.bounds.union(endSelectedLineLayout.bounds).intersects(dirtyRect) else {
        //    return
        // }

        logger.debug("drawSelection \(selectionRange)")

        context.saveGState()
        context.setFillColor(NSColor.selectedTextBackgroundColor.cgColor)
        context.setShouldAntialias(false)

        if startSelectedLineIndex <= endSelectedLineIndex {
            for lineIndex in startSelectedLineIndex...endSelectedLineIndex {
                guard let lineLayout = _layoutManager.lineLayout(index: lineIndex) else {
                    continue
                }

                let startPositionX: CGFloat
                let rectWidth: CGFloat

                if lineIndex == startSelectedLineIndex {
                    // start - partial selection
                    let startCharacterPositionOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, selectionRange.start.character, nil)
                    let endPositionOffset = CTLineGetOffsetForStringIndex(startSelectedLineLayout.ctline, selectionRange.end.character, nil)
                    startPositionX = lineLayout.bounds.origin.x + startCharacterPositionOffset

                    if startSelectedLineLayout != endSelectedLineLayout {
                        // selection that ends on another line ends at the end of the view
                        // not at the end of the line
                        rectWidth = frame.width - lineLayout.bounds.origin.x
                    } else {
                        rectWidth = endPositionOffset - startCharacterPositionOffset
                    }
                } else if lineIndex == endSelectedLineIndex {
                    // end - partial selection
                    let endCharacterPositionOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, selectionRange.end.character, nil)
                    startPositionX = 0
                    rectWidth = endCharacterPositionOffset + lineLayout.bounds.origin.x
                } else {
                    // x + 1..<y full line selection
                    startPositionX = frame.minX // currentLineLayout.origin.x
                    rectWidth = frame.width
                }

                context.fill(CGRect(x: startPositionX,
                                    y: lineLayout.bounds.origin.y,
                                    width: rectWidth,
                                    height: lineLayout.bounds.height).insetBy(dx: 0, dy: -lineLayout.lineSpacing / 2)
                )
            }
        }

        if startSelectedLineIndex > endSelectedLineIndex {
            for lineIndex in endSelectedLineIndex...startSelectedLineIndex {
                guard let lineLayout = _layoutManager.lineLayout(index: lineIndex) else {
                    continue
                }

                let startPositionX: CGFloat
                let rectWidth: CGFloat

                if lineIndex == startSelectedLineIndex {
                    // start - partial selection from the beginning to the start selection
                    let startCharacterPositionOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, selectionRange.start.character, nil)
                    startPositionX = 0
                    rectWidth = startCharacterPositionOffset + lineLayout.bounds.origin.x
                } else if lineIndex == endSelectedLineIndex {
                    // end - partial selection from the end to the end of the line
                    let endCharacterPositionOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, selectionRange.end.character, nil)
                    let startPositionOffset = CTLineGetOffsetForStringIndex(startSelectedLineLayout.ctline, selectionRange.start.character, nil)
                    startPositionX = lineLayout.bounds.origin.x + endCharacterPositionOffset

                    if startSelectedLineLayout != endSelectedLineLayout {
                        // selection that ends on another line ends at the end of the view
                        // not at the end of the line
                        rectWidth = frame.width - lineLayout.bounds.origin.x
                    } else {
                        rectWidth = startPositionOffset - endCharacterPositionOffset
                    }
                } else {
                    // x + 1..<y full line selection
                    startPositionX = frame.minX // currentLineLayout.origin.x
                    rectWidth = frame.width
                }

                context.fill(CGRect(x: startPositionX,
                                    y: lineLayout.bounds.origin.y,
                                    width: rectWidth,
                                    height: lineLayout.bounds.height).insetBy(dx: 0, dy: -lineLayout.lineSpacing / 2)
                )
            }
        }
        context.restoreGState()
    }

    public override func layout() {
        layoutText()
        super.layout()
    }

    /// Layout visible text and adjust view frame
    private func layoutText() {
        var visibleRect = enclosingScrollView?.documentVisibleRect ?? frame
        if let scrollView = enclosingScrollView, let verticalRulerView = scrollView.verticalRulerView , scrollView.rulersVisible == true {
            let rulerWidth = verticalRulerView.requiredThickness

            visibleRect = NSRect(
                origin: scrollView.documentVisibleRect.origin,
                size: NSSize(width: scrollView.documentVisibleRect.width - rulerWidth, height: scrollView.documentVisibleRect.height)
            )
        }

        // FIXME: the size is few pixels too wide
        let newTextContentSize = _layoutManager.layoutText(font: configuration.font,
                                                           color: configuration.textColor.cgColor,
                                                           frame: visibleRect)


        if frame.size != newTextContentSize {
            frame.size = newTextContentSize
            scrollToVisible(visibleRect)
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

// MARK: - NSTextInputClient

// The default implementation of the NSView method inputContext manages
// an NSTextInputContext instance automatically if the view subclass conforms
// to the NSTextInputClient protocol.
extension CodeEditView: NSTextInputClient {
    public func insertText(_ string: Any, replacementRange: NSRange) {
        insertText(
            string,
            replacementRange: replacementRange,
            registerUndo: false
        )
    }

    private func insertText(_ string: Any, replacementRange: NSRange, registerUndo shouldRegisterUndoAction: Bool) {
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

        // delete selected area
        delete(self)

        // insert text
        logger.debug("insertText \(string) replacementRange \(replacementRange)")
        if replacementRange.location != NSNotFound {
            let start = _textStorage.position(atCharacterIndex: replacementRange.location)!
            let end = _textStorage.position(atCharacterIndex: replacementRange.location + replacementRange.length)!
            _textStorage.remove(range: Range(start: start, end: end))
            _textStorage.insert(string: string, at: start)
            _caret.position = start
        } else {

            if shouldRegisterUndoAction {
                let caretPosition = _caret.position
                undoManager?.setActionName("Typing")
                undoManager?.registerUndo(withTarget: _textStorage) {
                    $0.remove(
                        range: Range(
                            start: caretPosition,
                            end: caretPosition.position(after: string.count, in: $0) ?? caretPosition
                        )
                    )

                    self._caret.position = caretPosition

                    self.needsLayout = true
                    self.needsDisplay = true
                }
            }

            _textStorage.insert(string: string, at: _caret.position)
        }

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

    /// Called by the input manager to set text which might be combined with further input to form the final text (e.g. composition of ^ and a to â).
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard let string = string as? String else {
            return
        }

        // (??) If there is no marked text, the current selection is replaced.
        // If there is no selection, the string is inserted at the insertion point.
        if selectedRange.location != NSNotFound {
            insertText(
                string,
                replacementRange: replacementRange
            )
        }

        logger.debug("setMarkedText \(string) selectedRange \(selectedRange) replacementRange \(replacementRange)")
    }

    public func unmarkText() {
        // When it is called? This API needs more investigation
        logger.debug("unmarkText")
        _markedRange = NSRange(location: NSNotFound, length: 0)
    }

    public func selectedRange() -> NSRange {
        logger.debug("selectedRange")

        guard let selectionRange = _textSelection?.range else {
            // Return caret position to make the mark selection working
            let caretCharacterIndex = _textStorage.characterIndex(at: _caret.position)
            return NSRange(location: caretCharacterIndex, length: 0)
        }

        // _selectionRange -> NSRange
        let startIndex = _textStorage.characterIndex(at: selectionRange.start)
        let endIndex = _textStorage.characterIndex(at: selectionRange.end)

        return NSRange(location: startIndex, length: endIndex - startIndex)
    }

    public func markedRange() -> NSRange {
        _markedRange
    }

    public func hasMarkedText() -> Bool {
        _markedRange.location != NSNotFound
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        logger.debug("attributedSubstring forProposedRange \(range)")
        return NSAttributedString()
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let position = _textStorage.position(atCharacterIndex: range.location),
           let caretBounds = _layoutManager.caretBounds(at: position),
           let rect = window?.convertToScreen(convert(caretBounds, to: nil)) else {
            return .zero
        }

        return rect
    }

    public func characterIndex(for point: NSPoint) -> Int {
        guard let position = _layoutManager.position(at: point) else {
            return NSNotFound
        }

        return _textStorage.characterIndex(at: position)
    }
}

// MARK: - Commands

extension CodeEditView {

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
            selectedString = String(_textStorage.string(in: selectionRange)!)
        } else {
            selectedString = String(_textStorage.string(in: selectionRange.inverted())!)
        }

        updatePasteboard(with: selectedString)
    }

    @objc func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string) else {
            return
        }

        self.insertText(
            string,
            registerUndo: true
        )
    }

    @objc func cut(_ sender: Any?) {
        undoManager?.beginUndoGrouping()
        self.copy(sender)
        self.delete(sender)
        undoManager?.endUndoGrouping()
    }

    @objc func delete(_ sender: Any?) {
        guard let selectionRange = _textSelection?.range else {
            return
        }

        let removeRange: Range
        let caretPosition: Position
        if selectionRange.start > selectionRange.end {
            removeRange = selectionRange.inverted()
            caretPosition = selectionRange.end
        } else {
            removeRange = selectionRange
            caretPosition = selectionRange.start
        }

        let removedString = String(_textStorage.string(in: removeRange) ?? "")
        undoManager?.setActionName("Delete")
        undoManager?.registerUndo(withTarget: _textStorage) {
            $0.insert(string: removedString, at: caretPosition)
            self._caret.position = removeRange.end
            self.needsLayout = true
            self.needsDisplay = true
        }

        _textStorage.remove(range: removeRange)
        _caret.position = caretPosition

        unselectText()
        needsLayout = true
        needsDisplay = true
    }

    public override func uppercaseWord(_ sender: Any?) {
        // Find word at current position
        // change it
        #warning("uppercaseWord")
    }

    public override func lowercaseWord(_ sender: Any?) {
        #warning("lowercaseWord")
    }

    public override func capitalizeWord(_ sender: Any?) {
        #warning("capitalizeWord")
    }

    public override func selectAll(_ sender: Any?) {
        let lastLineString = _textStorage.string(line: _textStorage.linesCount - 1)
        _textSelection = SelectionRange(Range(start: Position(line: 0, character: 0), end: Position(line: _textStorage.linesCount - 1, character: lastLineString.count - 1)))
        needsDisplay = true
    }

    public override func selectLine(_ sender: Any?) {
        _textSelection = SelectionRange(Range(start: Position(line: _caret.position.line, character: 0), end: Position(line: _caret.position.line, character: _textStorage.string(line: _caret.position.line).count - 1)))
        needsDisplay = true
    }

    public override func selectParagraph(_ sender: Any?) {
        #warning("selectParagraph")
    }

    public override func selectWord(_ sender: Any?) {
        #warning("selectWord")
    }

    private func insertText(_ insertString: Any, registerUndo: Bool) {
        guard let string = insertString as? String else {
            return
        }

        insertText(
            string,
            replacementRange: NSRange(location: NSNotFound, length: 0),
            registerUndo: registerUndo
        )
    }

    public override func insertText(_ insertString: Any) {
        insertText(
            insertString,
            registerUndo: false
        )
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

        let removeRange: Range
        let startingCarretPosition = _caret.position

        if let oneCharBeforePosition = _caret.position.position(before: 1, in: _textStorage) {
            _caret.position = oneCharBeforePosition
            removeRange = Range(start: oneCharBeforePosition, end: startingCarretPosition)
        } else {
            // move to the previous line
            let lineNumber = _caret.position.line - 1
            if lineNumber >= 0 {
                let prevLineString = _textStorage.string(line: lineNumber)
                _caret.position = Position(line: lineNumber, character: prevLineString.count - 1)
                removeRange = Range(start: _caret.position, end: startingCarretPosition)
            } else {
                removeRange = Range(start: _caret.position, end: startingCarretPosition)
                assertionFailure("Should not happen")
            }
        }

        let removedString = String(_textStorage.string(in: removeRange) ?? "")
        undoManager?.setActionName("Delete")
        undoManager?.registerUndo(withTarget: _textStorage) {
            $0.insert(string: removedString, at: removeRange.start)
            self._caret.position = startingCarretPosition
            self.needsLayout = true
            self.needsDisplay = true
        }

        _textStorage.remove(range: removeRange)
    }

    public override func deleteForward(_ sender: Any?) {
        unselectText()

        let removeRange = Range(start: _caret.position, end: Position(line: _caret.position.line, character: _caret.position.character + 1))
        let removedString = String(_textStorage.string(in: removeRange) ?? "")
        let caretPosition = _caret.position
        undoManager?.setActionName("Delete")
        undoManager?.registerUndo(withTarget: _textStorage) {
            $0.insert(string: removedString, at: caretPosition)
            self._caret.position = caretPosition
            self.needsLayout = true
            self.needsDisplay = true
        }

        _textStorage.remove(range: removeRange)

        needsLayout = true
        needsDisplay = true
    }

    public override func moveUp(_ sender: Any?) {
        if let selectionRange = _textSelection?.range {
            if selectionRange.start > selectionRange.end {
                _caret.position = selectionRange.end
            } else {
                _caret.position = selectionRange.start
            }
        }

        unselectText()
        _caret.position.moveUpByLine(using: _layoutManager)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveUpAndModifySelection(_ sender: Any?) {
        moveSelection(.up, by: 1)
        if let endSelectionRange = _textSelection?.range.end {
            scrollToVisiblePosition(endSelectionRange)
        }
        needsDisplay = true
    }

    public override func moveDown(_ sender: Any?) {
        if let selectionRange = _textSelection?.range {
            if selectionRange.start > selectionRange.end {
                _caret.position = selectionRange.start
            } else {
                _caret.position = selectionRange.end
            }
        }

        unselectText()
        _caret.position.moveDownByLine(using: _layoutManager)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveDownAndModifySelection(_ sender: Any?) {
        moveSelection(.down, by: 1)
        if let endSelectionRange = _textSelection?.range.end {
            scrollToVisiblePosition(endSelectionRange)
        }
        needsDisplay = true
    }

    public override func moveLeft(_ sender: Any?) {
        if let selectionRange = _textSelection?.range {
            if selectionRange.start > selectionRange.end {
                _caret.position = selectionRange.end
            } else {
                _caret.position = selectionRange.start
            }
        } else {
            _caret.position.move(by: -1, in: _textStorage)
        }

        unselectText()
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveLeftAndModifySelection(_ sender: Any?) {
        moveSelection(.left, by: 1)
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
        var startSelectionPosition = _textSelection?.range.start ?? _caret.position
        let endSelectionPosition = _textSelection?.range.end ?? _caret.position

        // update start
        startSelectionPosition = Position(line: startSelectionPosition.line, character: 0)

        _textSelection = SelectionRange(Range(start: startSelectionPosition, end: endSelectionPosition))
        scrollToVisiblePosition(startSelectionPosition)
        needsDisplay = true
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

        _caret.position.move(by: 1, in: _textStorage)
    }

    public override func moveRightAndModifySelection(_ sender: Any?) {
        moveSelection(.right, by: 1)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToRightEndOfLine(_ sender: Any?) {
        unselectText()
        _caret.position = Position(line: _caret.position.line, character: _textStorage.string(line: _caret.position.line).count - 1)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        let startSelectionPosition = _textSelection?.range.start ?? _caret.position
        var endSelectionPosition = _textSelection?.range.end ?? _caret.position

        // update end
        endSelectionPosition = Position(line: endSelectionPosition.line, character: _textStorage.string(line: endSelectionPosition.line).count - 1)

        _textSelection = SelectionRange(Range(start: startSelectionPosition, end: endSelectionPosition))
        scrollToVisiblePosition(endSelectionPosition)
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

        let lastLineString = _textStorage.string(line: _textStorage.linesCount - 1)
        _caret.position = Position(line: _textStorage.linesCount - 1, character: lastLineString.count - 1)
        scrollToVisiblePosition(_caret.position)
        needsDisplay = true
    }

    public override func insertNewline(_ sender: Any?) {
        unselectText()
        self.insertText("\n", registerUndo: true)
        _caret.position = Position(line: _caret.position.line, character: 0)
        scrollToVisiblePosition(_caret.position)
    }

    public override func insertLineBreak(_ sender: Any?) {
        unselectText()
        insertNewline(sender)
        scrollToVisiblePosition(_caret.position)
    }

    public override func insertTab(_ sender: Any?) {

        if configuration.insertSpacesForTab {
            insertText(
                String([Character](repeating: " ", count: configuration.tabSpaceSize)),
                replacementRange: NSRange(location: NSNotFound, length: 0),
                registerUndo: true
            )
        } else {
            insertText(
                "\t",
                replacementRange: NSRange(location: NSNotFound, length: 0),
                registerUndo: true
            )
        }
        scrollToVisiblePosition(_caret.position)
    }

    private func moveSelection(_ direction: MoveDirection, by count: Int) {
        let startSelectionPosition = _textSelection?.range.start ?? _caret.position
        var endSelectionPosition = _textSelection?.range.end ?? _caret.position

        switch direction {
            case .right:
                endSelectionPosition.move(by: 1, in: _textStorage)
            case .left:
                endSelectionPosition.move(by: -1, in: _textStorage)
            case .up:
                endSelectionPosition.moveUpByLine(using: _layoutManager)
            case .down:
                endSelectionPosition.moveDownByLine(using: _layoutManager)
        }

        _textSelection = SelectionRange(Range(start: startSelectionPosition, end: endSelectionPosition))
    }
}
