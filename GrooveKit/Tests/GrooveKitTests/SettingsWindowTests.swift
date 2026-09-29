import Testing
@testable import GrooveKit

@Suite struct SettingsWindowTests {
    @Test func startAfterEndPushesEnd() {
        var s = GrooveSettings()
        s.setWindowStart(21 * 60)
        #expect(s.windowStartMinutes == 21 * 60)
        #expect(s.windowEndMinutes == 21 * 60 + 45)
    }

    @Test func endBeforeStartPullsStart() {
        var s = GrooveSettings()
        s.setWindowEnd(7 * 60)
        #expect(s.windowEndMinutes == 7 * 60)
        #expect(s.windowStartMinutes == 6 * 60 + 15)
    }

    @Test func staysInsideTheDay() {
        var s = GrooveSettings()
        s.setWindowStart(23 * 60 + 50)
        #expect(s.windowStartMinutes == 23 * 60 + 59 - 45)
        #expect(s.windowEndMinutes == 23 * 60 + 59)
        s.setWindowEnd(0)
        #expect(s.windowEndMinutes == 45)
        #expect(s.windowStartMinutes == 0)
    }

    @Test func normalEditsKeepTheOtherBound() {
        var s = GrooveSettings()
        s.setWindowStart(9 * 60)
        s.setWindowEnd(19 * 60)
        #expect(s.windowStartMinutes == 9 * 60)
        #expect(s.windowEndMinutes == 19 * 60)
    }
}
