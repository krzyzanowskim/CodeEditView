import Cocoa

public class EditorRulerView: NSRulerView {

    public init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .horizontalRuler)

        precondition(scrollView.documentView != nil, "NSScrollView.documentView is not set")
        self.clientView = scrollView.documentView

        ruleThickness = 24
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let codeEditView = clientView as? CodeEditView else { return }


        let relativePoint = self.convert(CGPoint.zero, from: codeEditView)

        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: isFlipped ? -1 : 1)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: codeEditView.configuration.font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        var currentLineNumber = Int.min
        for lineLayout in codeEditView._layoutManager.linesLayouts(in: CGRect(x: 0, y: codeEditView.visibleRect.origin.y, width: 0, height: codeEditView.visibleRect.size.height)) {
            if lineLayout.lineNumber != currentLineNumber {
                currentLineNumber = lineLayout.lineNumber

                let ctline = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, "\(currentLineNumber + 1)" as CFString, attributes as CFDictionary))
                let ctlineWidth = CGFloat(CTLineGetTypographicBounds(ctline, nil, nil, nil))

                context.textPosition = lineLayout.bounds.offsetBy(dx: (frame.width - 4) - ctlineWidth, dy: lineLayout.baseline.y + relativePoint.y).origin
                CTLineDraw(ctline, context)
            }
        }

        context.restoreGState()
        //super.drawHashMarksAndLabels(in: rect)
    }
}
