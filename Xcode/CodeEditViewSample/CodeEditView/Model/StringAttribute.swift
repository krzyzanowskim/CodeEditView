import CoreGraphics
import CoreText
import Cocoa

public extension String {

    struct AttributeKey {
        let foreground: NSColor
        let font: CTFont
    }

    struct Attribute<Key, Value>: Hashable where Key: KeyPath<String.AttributeKey, Value>, Value: Hashable {

        private let key: Key
        private let value: Value

        init(_ key: Key, _ value: Value) {
            self.key = key
            self.value = value
        }
    }
}
