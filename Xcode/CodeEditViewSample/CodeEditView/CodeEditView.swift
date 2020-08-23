import Cocoa
import CoreText

/// Code Edit View
public class CodeEditView: NSView {

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

    /// Line Wrapping mode
    public var lineWrapping: LineWrapping = .bounds
    /// Line Spacing mode
    public var lineSpacing: Spacing = .normal

    private var _lineBreakWidth: Double {
        switch lineWrapping {
            case .none:
                return Double.infinity
            case .bounds:
                return Double(bounds.width)
            case .width(let width):
                return Double(width)
        }

    }
    private let storage: TextStorage

    public init(storage: TextStorage) {
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

        // Let's draw some text. Top Bottom/Left Right
        let contentRange: Swift.Range<Position> = Position(line: 0, character: 0)..<Position(line: storage.linesCount, character: 0)
        if let string = storage[contentRange] {
            let attributedString = CFAttributedStringCreate(nil, string as CFString, nil)!
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
            let stringLength = string.utf16.count

            // Top Bottom/Left Right
            let posX: CGFloat = 0
            var posY: CGFloat = bounds.height // + scroll offset

            var lineStartIndex: CFIndex = 0
            // alignmentRectInsets? safeAreaInsets?
            while lineStartIndex < stringLength {
                let breakIndex = CTTypesetterSuggestLineBreakWithOffset(typesetter, lineStartIndex, _lineBreakWidth, Double(posX))
                let leftRange = CFRange(location: lineStartIndex, length: breakIndex)
                let ctline = CTTypesetterCreateLineWithOffset(typesetter, leftRange, Double(posX))

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(ctline, &ascent, &descent, &leading)

                // print line
                if let context = NSGraphicsContext.current?.cgContext {
                    // origin position
                    context.textPosition = .init(x: 0, y: posY - (ascent + descent))
                    CTLineDraw(ctline, context)
                }

                lineStartIndex += breakIndex
                posY -= (ascent + descent + leading) * lineSpacing.rawValue
            }
        }
    }
}

import SwiftUI

struct CodeEditView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEdit(text: sampleText)
            .frame(maxWidth: 300, maxHeight: .infinity)
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
