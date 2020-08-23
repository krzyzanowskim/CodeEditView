import Cocoa
import CoreText

/// Code Edit View
public class CodeEditView: NSView {
    private let storage: TextStorage

    init(storage: TextStorage) {
        self.storage = storage
        
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // draw text
        // 1. find text range for displayed dirtyRect
        // 2. draw text from the range

        // 
    }
}
