import Cocoa

public enum CaretStyle {
    case line
    case block
}

final class CaretView: NSView {
    var style: CaretStyle = .line

    private var caretVisible: Bool = true
    private let timeInterval: TimeInterval = 0.65
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + self.timeInterval, repeating: timeInterval)
        t.setEventHandler(handler: { [weak self] in
            DispatchQueue.main.async {
                self?.caretVisible.toggle()
                self?.needsDisplay = true
            }
        })
        return t
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        timer.resume()
    }

    func startBlink() {
        timer.resume()
    }

    func stopBlink() {
        timer.suspend()
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
        context.fill(CGRect(x: 0, y: 0, width: max(1, frame.width * 0.1), height: bounds.height))
    }

    private func drawBlockStyle(in context: CGContext, dirtyRect: NSRect) {
        context.setFillColor(NSColor.textColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
    }
}
