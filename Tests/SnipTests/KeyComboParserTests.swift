import XCTest
@testable import Snip

final class KeyComboParserTests: XCTestCase {

    func testParseSingleCombo() {
        let set = KeyboardWatcher.parseComboString("cmd+c")
        XCTAssertEqual(set.count, 1)
        let hk = set.first!
        XCTAssertEqual(hk.keyCode, 8) // c
        XCTAssertTrue(hk.modifiers.contains(.command))
        XCTAssertFalse(hk.modifiers.contains(.shift))
    }

    func testParseMultipleCombos() {
        let set = KeyboardWatcher.parseComboString("cmd+c,cmd+v,cmd+shift+z")
        XCTAssertEqual(set.count, 3)
    }

    func testParseWithSpaces() {
        let set = KeyboardWatcher.parseComboString("cmd + c , cmd + v")
        XCTAssertEqual(set.count, 2)
    }

    func testParseCommandAlternative() {
        let set1 = KeyboardWatcher.parseComboString("cmd+c")
        let set2 = KeyboardWatcher.parseComboString("command+c")
        XCTAssertEqual(set1, set2)
    }

    func testParseOptionAlternative() {
        let set1 = KeyboardWatcher.parseComboString("opt+c")
        let set2 = KeyboardWatcher.parseComboString("option+c")
        XCTAssertEqual(set1, set2)
    }

    func testParseControlAlternative() {
        let set1 = KeyboardWatcher.parseComboString("ctrl+c")
        let set2 = KeyboardWatcher.parseComboString("control+c")
        XCTAssertEqual(set1, set2)
    }

    func testParseInvalidKeyReturnsEmpty() {
        let set = KeyboardWatcher.parseComboString("cmd+xyz")
        XCTAssertEqual(set.count, 0)
    }

    func testEmptyString() {
        let set = KeyboardWatcher.parseComboString("")
        XCTAssertEqual(set.count, 0)
    }

    func testDefaultCombosCount() {
        XCTAssertGreaterThan(KeyboardWatcher.defaultCombos.count, 5)
    }
}