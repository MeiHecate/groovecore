import XCTest
import GrooveKit
@testable import GrooveCore

final class MonthGridTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()

    func testSeptember2026StartsOnTuesday() {
        let cells = MonthGrid.cells(year: 2026, month: 9, calendar: cal)
        XCTAssertEqual(cells.count, 31)
        XCTAssertNil(cells[0])
        XCTAssertEqual(cells[1], LocalDay(year: 2026, month: 9, day: 1))
        XCTAssertEqual(cells.last!, LocalDay(year: 2026, month: 9, day: 30))
    }

    func testFebruary2026StartsOnSunday() {
        let cells = MonthGrid.cells(year: 2026, month: 2, calendar: cal)
        XCTAssertEqual(cells.prefix(6).compactMap { $0 }.count, 0)
        XCTAssertEqual(cells.count, 6 + 28)
    }
}
