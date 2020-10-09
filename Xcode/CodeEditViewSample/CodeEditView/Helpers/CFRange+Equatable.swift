import CoreFoundation

extension CFRange: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.location == rhs.location &&
            lhs.length == rhs.length
    }
}
