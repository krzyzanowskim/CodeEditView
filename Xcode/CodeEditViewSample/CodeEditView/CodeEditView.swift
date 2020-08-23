import Cocoa

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
    }
}
