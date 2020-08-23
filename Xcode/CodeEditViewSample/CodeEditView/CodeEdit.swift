import SwiftUI

/// SwiftUI wrapper
public struct CodeEdit: View {
    @State public var text: String

    public var body: some View {
        CodeEditViewRepresentable(text: $text)
    }
}

private final class CodeEditViewRepresentable: NSViewRepresentable {
    @Binding private var text: String
    private let textStorage: TextStorage

    init(text: Binding<String>) {
        _text = text
        textStorage = TextStorage(string: text.wrappedValue)
    }

    func makeNSView(context: Context) -> some NSView {
        return CodeEditView(storage: textStorage)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        //
    }
}
