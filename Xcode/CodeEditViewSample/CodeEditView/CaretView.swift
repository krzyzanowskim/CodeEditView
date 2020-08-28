import Cocoa

public enum CaretStyle {
    case line
    case block
}

final class CaretView: NSView {
    var style: CaretStyle = .line

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        switch style {
            case .line:
                drawLineStyle(in: context, dirtyRect: dirtyRect)
            case .block:
                drawBlockStyle(in: context, dirtyRect: dirtyRect)
        }
    }

    private func drawLineStyle(in context: CGContext, dirtyRect: NSRect) {
        context.setFillColor(NSColor.textColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 2, height: bounds.height))
    }

    private func drawBlockStyle(in context: CGContext, dirtyRect: NSRect) {
        context.setFillColor(NSColor.textColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
    }
}
