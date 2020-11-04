import XCTest
@testable import CodeEditView

class StringTextStorageProviderTests: XCTestCase {

    func testProvider() {
        let storageProvider = StringTextStorageProvider()
        XCTAssertEqual(storageProvider.linesCount, 0)
        storageProvider.insert(string: "test", at: Position(line: 0, character: 0))
        XCTAssertEqual(storageProvider.linesCount, 1)
        XCTAssertEqual(storageProvider.character(at: Position(line: 0, character: 1)), "e")
    }

    func testRemove1() {
        let storageProvider = StringTextStorageProvider()
        storageProvider.insert(string: "test", at: Position(line: 0, character: 0))
        XCTAssertEqual(storageProvider.string(line: 0), "test")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(storageProvider.string(line: 0), "test")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)))
        XCTAssertEqual(storageProvider.string(line: 0), "est")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)))
        XCTAssertEqual(storageProvider.string(line: 0), "st")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)))
        XCTAssertEqual(storageProvider.string(line: 0), "t")
        storageProvider.remove(range: Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)))
        XCTAssertEqual(storageProvider.string(line: 0), "")
    }

    func testPositionOffset() {
        let storageProvider = StringTextStorageProvider()
        storageProvider.insert(string: "test\ntest2\ntest3", at: Position(line: 0, character: 0))
        let index = storageProvider.characterIndex(at: Position(line: 2, character: 2))
        XCTAssertEqual(index, 13)
    }
}
