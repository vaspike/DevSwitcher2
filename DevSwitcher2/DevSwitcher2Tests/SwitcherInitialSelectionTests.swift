import XCTest
@testable import DevSwitcher2

final class SwitcherInitialSelectionTests: XCTestCase {
    func testNextItemIsSelectedByDefaultWithMultipleItems() {
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 4, selectNext: true), 1)
    }

    func testCurrentItemRemainsSelectedWhenPreferenceIsDisabled() {
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 4, selectNext: false), 0)
    }

    func testSingleItemAlwaysSelectsCurrentItem() {
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 1, selectNext: true), 0)
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 1, selectNext: false), 0)
    }

    func testEmptyCandidatesUseZeroIndex() {
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 0, selectNext: true), 0)
        XCTAssertEqual(WindowManager.initialSelectionIndex(itemCount: 0, selectNext: false), 0)
    }
}
