import XCTest
@testable import CodeEditView

final class RangeTests: XCTestCase {
    func testIntersection() {
        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 101), end: Position(line: 0, character: 199)))
        )

        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200)))
        )

        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 50), end: Position(line: 0, character: 150)))
        )

        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 150), end: Position(line: 0, character: 250)))
        )

        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 150), end: Position(line: 0, character: 200)))
        )

        XCTAssertTrue(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 150)))
        )

        XCTAssertFalse(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 50), end: Position(line: 0, character: 100)))
        )

        XCTAssertFalse(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 200), end: Position(line: 0, character: 250)))
        )

        XCTAssertFalse(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 50), end: Position(line: 0, character: 90)))
        )

        XCTAssertFalse(
            Range(start: Position(line: 0, character: 100), end: Position(line: 0, character: 200))
                .overlaps(Range(start: Position(line: 0, character: 250), end: Position(line: 0, character: 300)))
        )
    }
}
