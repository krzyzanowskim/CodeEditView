extension Sequence {
    @inlinable
    func count(isIncluded: (Element) -> Bool) -> Int {
        var count = 0
        for x in self {
            if isIncluded(x) {
                count += 1
            }
        }
        return count
    }
}
