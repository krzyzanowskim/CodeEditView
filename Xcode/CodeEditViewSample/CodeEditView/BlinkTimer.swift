import Foundation
import Dispatch

final class BlinkTimer {
    /// Blink delay
    static let delay: Double = 0.55
    /// Whether caret should be visible
    var caretIsVisible: Bool

    private let timer: DispatchSourceTimer
    private var handler: ((_ visible: Bool) -> Void)?

    init() {
        caretIsVisible = true
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: Self.delay)
    }

    deinit {
        timer.setEventHandler(handler: {})
        timer.cancel()
    }

    func setEventHandler(_ onUpdate: @escaping (_ visible: Bool) -> Void) {
        handler = onUpdate
        timer.setEventHandler { [unowned self] in
            guard !timer.isCancelled else {
                return
            }
            caretIsVisible.toggle()
            onUpdate(caretIsVisible)
        }
    }

    func resume(_ after: DispatchTimeInterval? = nil) {
        caretIsVisible = true

        timer.schedule(deadline: .now() + (after ?? .milliseconds(Int(Self.delay * 1000))) , repeating: Self.delay)
        timer.resume()
    }

    func suspend() {
        caretIsVisible = true
        handler?(caretIsVisible)
        timer.suspend()
    }
}
