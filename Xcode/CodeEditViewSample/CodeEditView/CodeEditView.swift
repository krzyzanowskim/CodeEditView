import Cocoa
import CoreText
import OSLog

// Ref: Creating Custom Views
//      https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/Tasks/TextViewTask.html#//apple_ref/doc/uid/TP40008899-BCICEFGE
//
// TODO:
//  - Text Checking: NSTextCheckingClient, NSTextCheckingController
//  - tell the input context when position information for a character range changes, when the text view scrolls, by sending the invalidateCharacterCoordinates message to the input context.

/// Code Edit View
public final class CodeEditView: NSView {

    private typealias LineNumber = Int

    public enum LineWrapping {
        /// No wrapping
        case none
        /// Wrap at bounds
        case bounds
        /// Wrap at specific width
        case width(_ value: CGFloat = -1)
    }

    public enum Spacing: CGFloat {
        /// 0% line spacing
        case tight = 1.0
        /// 20% line spacing
        case normal = 1.2
        /// 40% line spacing
        case relaxed = 1.4
    }

    /// Visible line layout
    private struct LineLayout {
        let lineIndex: Int
        let ctline: CTLine
        /// A point that specifies the x and y values at which line is to be drawn, in user space coordinates.
        /// A line origin based position.
        let origin: CGPoint
        let lineHeight: CGFloat
        let lineDescent: CGFloat
        let stringRange: CFRange
    }

    /// Line Wrapping mode
    public var lineWrapping: LineWrapping {
        didSet {
            needsLayout = true
        }
    }
    /// Line Spacing mode
    public var lineSpacing: Spacing {
        didSet {
            needsLayout = true
        }
    }

    public var font: NSFont? = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular) {
        didSet {
            needsLayout = true
        }
    }

    private let _caretView: CaretView
    private var _caretPosition: Position {
        didSet {
            needsLayout = true
        }
    }

    /// Whether or not this view is the focused view for its window
    private var _isFirstResponder = false {
        didSet {
            self._caretView.isHidden = !_isFirstResponder
        }
    }

    private let _storage: TextStorage

    /// Visible lines layout
    private var _lineLayouts: [LineLayout]

    public init(storage: TextStorage) {
        self._storage = storage

        self._lineLayouts = []
        self._lineLayouts.reserveCapacity(200)

        self.lineSpacing = .normal
        self.lineWrapping = .bounds

        self._caretView = CaretView()
        self._caretPosition = .zero

        super.init(frame: .zero)

        self.addSubview(_caretView)
        _caretView.isHidden = true
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

    public override func doCommand(by selector: Selector) {
        switch selector {
            case #selector(deleteBackward(_:)):
                deleteBackward(self)
            case #selector(moveUp(_:)):
                moveUp(self)
            case #selector(moveDown(_:)):
                moveDown(self)
            case #selector(moveLeft(_:)):
                moveLeft(self)
            case #selector(moveRight(_:)):
                moveRight(self)
            default:
                print("doCommand \(selector)")
                return
        }

        // If aSelector cannot be invoked, should not pass this message up the responder chain.
        // NSResponder also implements this method, and it does forward uninvokable commands up
        // the responder chain, but a text view should not.
        // super.doCommand(by: selector)
    }

    public override func deleteBackward(_ sender: Any?) {
        _caretPosition = Position(line: _caretPosition.line, character: max(0, _caretPosition.character - 1))
    }

    public override func moveUp(_ sender: Any?) {
        let currentLineLayoutIndex = _lineLayouts.firstIndex { lineLayout -> Bool in
            _caretPosition.character >= lineLayout.stringRange.location &&
                _caretPosition.character < lineLayout.stringRange.location + lineLayout.stringRange.length &&
                _caretPosition.line == lineLayout.lineIndex
        }

        if let idx = currentLineLayoutIndex, idx - 1 >= 0 {
            let currentLineLayout = _lineLayouts[idx]
            let prevLineLayout = _lineLayouts[idx - 1]
            let distance = min(_caretPosition.character - currentLineLayout.stringRange.location, prevLineLayout.stringRange.length - 1)
            _caretPosition = Position(line: prevLineLayout.lineIndex, character: prevLineLayout.stringRange.location + distance)
        }
    }

    public override func moveDown(_ sender: Any?) {
        // Find drawLayout for the current caret position
        let currentLineLayoutIndex = _lineLayouts.firstIndex { lineLayout -> Bool in
            _caretPosition.line == lineLayout.lineIndex &&
            _caretPosition.character >= lineLayout.stringRange.location && _caretPosition.character < lineLayout.stringRange.location + lineLayout.stringRange.length
        }

        if let idx = currentLineLayoutIndex, idx + 1 < _lineLayouts.count {
            let currentLineLayout = _lineLayouts[idx]
            let nextLineLayout = _lineLayouts[idx + 1]
            // distance from the beginning of the current line limited by the next line lenght
            // TODO: effectively reset caret position to the beginin of the line, while it's not expected
            //       the caret offset should preserve between lines, and empty line should not reset the caret offset.
            let distance = min(_caretPosition.character - currentLineLayout.stringRange.location, nextLineLayout.stringRange.length - 1)
            _caretPosition = Position(line: nextLineLayout.lineIndex, character: nextLineLayout.stringRange.location + distance)
        }
    }

    public override func moveLeft(_ sender: Any?) {
        _caretPosition = Position(line: _caretPosition.line, character: max(0, _caretPosition.character - 1))
    }

    public override func moveRight(_ sender: Any?) {
        _caretPosition = Position(line: _caretPosition.line, character: _caretPosition.character + 1)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        // draw text lines
        for lineLayout in _lineLayouts {
            context.textPosition = .init(x: lineLayout.origin.x, y: lineLayout.origin.y)
            CTLineDraw(lineLayout.ctline, context)
        }
    }

    public override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
    }

    public override func layout() {
        super.layout()
        layoutText()
        layoutCaret()
    }

    private func layoutCaret() {
        guard let lineLayout = lineLayout(for: _caretPosition) else { return }
        let characterOffset = CTLineGetOffsetForStringIndex(lineLayout.ctline, _caretPosition.character, nil)
        _caretView.frame = CGRect(x: lineLayout.origin.x + characterOffset, y: lineLayout.origin.y - lineLayout.lineDescent, width: 12, height: lineLayout.lineHeight - lineLayout.lineDescent)
    }

    /// Layout visible text
    private func layoutText() {
        // os_log(.debug, "layoutText")

        // Let's layout some text. Top Bottom/Left Right
        // TODO:
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
            let lineString = _storage[line: lineIndex]

            let attributedString = CFAttributedStringCreate(nil, lineString as CFString, [kCTFontAttributeName: font] as CFDictionary)!
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)

            var lineStartIndex: CFIndex = 0
            while lineStartIndex < lineString.count {
                let breakIndex = CTTypesetterSuggestLineBreakWithOffset(typesetter, lineStartIndex, Double(lineBreakWidth), Double(pos.y))
                let stringRange = CFRange(location: lineStartIndex, length: breakIndex)
                let ctline = CTTypesetterCreateLineWithOffset(typesetter, stringRange, Double(pos.x))

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading))
                let lineHeight = (ascent + descent + leading) * lineSpacing.rawValue

                // font origin based position
                _lineLayouts.append(
                    LineLayout(lineIndex: lineIndex,
                               ctline: ctline,
                               origin: CGPoint(x: 0, y: pos.y + (ascent + descent)),
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
            LineLayout(lineIndex: lineLayout.lineIndex,
                       ctline: lineLayout.ctline,
                       origin: CGPoint(x: lineLayout.origin.x, y: frame.height - lineLayout.origin.y),
                       lineHeight: lineLayout.lineHeight,
                       lineDescent: lineLayout.lineDescent,
                       stringRange: lineLayout.stringRange)
        }
    }

    // MARK: - Helpers

    private func lineLayout(for position: Position) -> LineLayout? {
        _lineLayouts.first {
            position.line == $0.lineIndex &&
                position.character >= $0.stringRange.location && position.character < $0.stringRange.location + $0.stringRange.length
        }
    }
}

// The default implementation of the NSView method inputContext manages
// an NSTextInputContext instance automatically if the view subclass conforms
// to the NSTextInputClient protocol.
extension CodeEditView: NSTextInputClient {

    public func insertText(_ string: Any, replacementRange: NSRange) {
        guard let nsstring = string as? NSString else {
            return
        }
        print("insertText \(nsstring) replacementRange \(replacementRange)")
        _caretPosition = Position(line: _caretPosition.line, character: _caretPosition.character + 1)
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        print("setMarkedText \(string) selectedRange \(selectedRange) replacementRange \(replacementRange)")
    }

    public func unmarkText() {
        print("unmarkText")
    }

    public func selectedRange() -> NSRange {
        print("selectedRange")
        return NSRange(location: NSNotFound, length: 0)
    }

    public func markedRange() -> NSRange {
        print("markedRange")
        return NSRange(location: NSNotFound, length: 0)
    }

    public func hasMarkedText() -> Bool {
        print("hasMarkedText")
        return false
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        print("attributedSubstring forProposedRange \(range)")
        return NSAttributedString()
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [.font, .backgroundColor, .foregroundColor]
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        print("firstRect forCharacterRange \(range)")
        return NSRect.zero
    }

    public func characterIndex(for point: NSPoint) -> Int {
        print("characterIndex \(point)")
        return NSNotFound
        //return 0
    }
}


// EDIT: - Preview

import SwiftUI

struct CodeEditView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEdit(text: sampleText)
            .frame(maxWidth: 400, maxHeight: .infinity)
    }

    private static let sampleText = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec cursus mattis nunc, vel rutrum dolor pharetra vel. Quisque vestibulum leo quis turpis rutrum faucibus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Phasellus eleifend ut quam at elementum. Duis sagittis lacus odio, id lacinia nibh dapibus eget. Mauris a orci quis tortor venenatis pellentesque. Ut convallis fermentum efficitur. Cras sodales at elit sed sagittis. Vestibulum consequat bibendum turpis, sit amet ullamcorper ante vestibulum eget. Ut non eros id ex euismod iaculis nec ac quam. Etiam non orci eu massa sagittis tincidunt. Nunc a turpis at lectus dignissim dapibus eget rhoncus risus.

Integer scelerisque egestas felis. Nullam ligula tellus, condimentum eu suscipit id, blandit a leo. Suspendisse suscipit eu libero eget congue. Duis sodales ligula tincidunt diam cursus luctus. Interdum et malesuada fames ac ante ipsum primis in faucibus. Aliquam eros nisl, sodales non tristique eget, scelerisque pellentesque ligula. Etiam luctus facilisis orci vel imperdiet. Vivamus ut suscipit risus. Vestibulum facilisis arcu eget odio dictum laoreet. Aliquam molestie odio vel elit aliquet tincidunt.

Morbi suscipit turpis nec ante congue laoreet. Nunc blandit posuere leo at accumsan. Interdum et malesuada fames ac ante ipsum primis in faucibus. Maecenas et ante lectus. In dignissim, quam eu egestas hendrerit, erat dolor commodo metus, sit amet suscipit nulla turpis at sem. Aenean a neque tincidunt, tincidunt arcu vel, faucibus dui. Pellentesque mollis ex congue fermentum placerat. Integer finibus hendrerit tellus. Ut quis lorem est. In justo lacus, suscipit semper ullamcorper sed, varius et felis. Etiam eu tellus vel risus consectetur eleifend. Sed a facilisis lectus.

Quisque condimentum sit amet quam non pretium. Maecenas vel justo tempor, ullamcorper orci sit amet, condimentum mauris. Cras sodales massa ut varius interdum. Nam sodales metus sit amet ligula suscipit consequat. In cursus faucibus fringilla. Vestibulum scelerisque diam justo, nec iaculis nisi efficitur vitae. Integer nec convallis lorem, a eleifend odio. Integer eget vestibulum magna. Vivamus ac mauris dictum, facilisis augue vitae, dictum erat. Sed a dictum orci. Cras nec dolor quis massa consequat tincidunt. Mauris ullamcorper quam finibus risus tempor, quis porta purus semper. Etiam non justo quis erat condimentum rutrum.

Duis augue leo, rutrum nec placerat at, gravida a metus. Proin vulputate rhoncus est et dapibus. Nam vestibulum libero sed libero porttitor suscipit. Sed pretium, nunc nec pretium hendrerit, risus arcu vulputate tortor, at dapibus urna ligula in nisl. Pellentesque imperdiet lectus ac pharetra aliquam. Etiam vulputate erat vitae libero fermentum finibus. Vivamus ac nisi tortor. Integer fringilla vel dolor at ullamcorper. Ut lacinia eros libero, vitae blandit lacus consequat ac. Quisque maximus commodo odio, ac congue tellus fringilla eu. Pellentesque feugiat ex id nibh auctor, non placerat massa finibus. Etiam bibendum semper aliquam. Mauris eros lacus, ultricies at leo ultrices, pellentesque consectetur tellus.

Nullam cursus magna eu erat sagittis, ut feugiat nunc egestas. Sed fringilla magna sit amet mattis rhoncus. Suspendisse condimentum dapibus enim vitae molestie. Praesent eget sem venenatis, vehicula ante sit amet, porttitor augue. Nulla vitae congue ipsum. Aenean egestas convallis enim, eu blandit lectus vehicula ac. Sed in auctor neque, sed porta neque. Proin libero lacus, vehicula vitae venenatis ut, ultricies ornare dolor. Mauris blandit urna mi, eu rhoncus lacus mollis et. Ut sollicitudin vehicula efficitur. Praesent id ante massa. In venenatis mi tellus, at congue massa dapibus sit amet.

Integer hendrerit enim quis leo venenatis bibendum at non nisi. Nulla ultrices iaculis lacinia. Etiam placerat tincidunt consectetur. Nulla facilisi. Fusce ut nibh in arcu placerat imperdiet. Vivamus maximus dolor a ligula rhoncus condimentum. Duis lacinia non turpis ut hendrerit. Nam dictum magna non turpis ultrices, consectetur dapibus magna lacinia. Praesent euismod pharetra purus eget condimentum.

Praesent scelerisque egestas magna, eget blandit lectus vehicula a. Fusce accumsan fringilla turpis, sed consectetur enim consectetur sit amet. Vestibulum id lectus ut tortor varius faucibus. Nunc sit amet ante congue, cursus nisl sit amet, egestas nisi. Donec finibus nec metus et viverra. Praesent eget tristique sapien. Donec iaculis mi sed velit vehicula, ac blandit metus scelerisque. Suspendisse ac leo nunc. Maecenas iaculis tortor eu placerat tincidunt. Nulla eget blandit magna. Donec magna libero, efficitur non aliquam a, iaculis et est. Suspendisse aliquam pellentesque urna in egestas.

Sed maximus mi dui, vel viverra metus commodo sit amet. Vestibulum aliquam euismod odio ac porttitor. Suspendisse hendrerit condimentum lobortis. Proin sed ipsum sodales, semper sapien non, convallis velit. Mauris non felis ut lectus hendrerit interdum nec quis erat. In lobortis egestas ipsum ac rhoncus. Donec sapien eros, dapibus non hendrerit nec, gravida dictum ligula. Curabitur vel quam lacus. Donec sed rhoncus orci. Cras vel viverra metus, a ultrices purus.

Pellentesque ac lectus justo. Pellentesque eu tellus sed odio venenatis scelerisque. Aliquam vitae magna purus. Sed a pretium nulla. Interdum et malesuada fames ac ante ipsum primis in faucibus. Aliquam convallis lacinia augue at consequat. Mauris dignissim magna ex, vel ultrices sem sodales non.
"""
}
