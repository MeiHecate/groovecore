import XCTest
@testable import GrooveCore

final class L10nTests: XCTestCase {
    func testFrenchEnglishAndFallback() {
        XCTAssertEqual(tr("tab.today", locale: Locale(identifier: "fr_FR")), "Aujourd'hui")
        XCTAssertEqual(tr("tab.today", locale: Locale(identifier: "en_US")), "Today")
        XCTAssertEqual(tr("tab.today", locale: Locale(identifier: "de_DE")), "Today")
        XCTAssertEqual(tr("exercise.pullups", locale: Locale(identifier: "fr_FR")), "Tractions")
    }
}
