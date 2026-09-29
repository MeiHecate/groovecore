import Foundation
import Testing
@testable import GrooveKit

@Suite struct SlotBuilderTests {
    @Test func defaultWindowGives17SlotsFrom8To20() {
        let slots = SlotBuilder.slots(on: day(2026, 9, 26), settings: GrooveSettings(), calendar: .paris)
        #expect(slots.count == 17)
        #expect(hm(slots.first!) == "08:00")
        #expect(hm(slots[1]) == "08:45")
        #expect(hm(slots.last!) == "20:00")
    }

    @Test func intervalBelowMinimumIsClamped() {
        var s = GrooveSettings(); s.intervalMinutes = 5
        #expect(s.effectiveInterval == 20)
        let slots = SlotBuilder.slots(on: day(2026, 9, 26), settings: s, calendar: .paris)
        #expect(hm(slots[1]) == "08:20")
    }

    @Test func restDayHasNoSlots() {
        var s = GrooveSettings(); s.restWeekdays = [1]
        #expect(SlotBuilder.slots(on: day(2026, 9, 27), settings: s, calendar: .paris).isEmpty)
        #expect(!SlotBuilder.slots(on: day(2026, 9, 26), settings: s, calendar: .paris).isEmpty)
    }

    @Test func startAfterEndHasNoSlotsAndEqualHasOne() {
        var s = GrooveSettings(); s.windowStartMinutes = 1200; s.windowEndMinutes = 480
        #expect(SlotBuilder.slots(on: day(2026, 9, 26), settings: s, calendar: .paris).isEmpty)
        s.windowEndMinutes = 1200
        #expect(SlotBuilder.slots(on: day(2026, 9, 26), settings: s, calendar: .paris).count == 1)
    }

    @Test func winterTimeChangeKeepsLocalWallClock() {
        // 25 Oct 2026: Paris goes from UTC+2 to UTC+1 at 03:00
        let s = GrooveSettings()
        let before = SlotBuilder.slots(on: day(2026, 10, 24), settings: s, calendar: .paris)
        let dst = SlotBuilder.slots(on: day(2026, 10, 25), settings: s, calendar: .paris)
        #expect(hm(dst.first!) == "08:00")
        #expect(hm(dst.last!) == "20:00")
        #expect(dst.first!.timeIntervalSince(before.first!) == 25 * 3600)
    }

    @Test func windowEndingJustBeforeMidnight() {
        var s = GrooveSettings(); s.windowStartMinutes = 22 * 60; s.windowEndMinutes = 23 * 60 + 59; s.intervalMinutes = 60
        let slots = SlotBuilder.slots(on: day(2026, 9, 26), settings: s, calendar: .paris)
        #expect(slots.map(hm) == ["22:00", "23:00"])
        #expect(slots.allSatisfy { LocalDay($0, calendar: .paris) == day(2026, 9, 26) })
    }
}
