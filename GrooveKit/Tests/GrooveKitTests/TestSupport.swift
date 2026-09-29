import Foundation
@testable import GrooveKit

extension Calendar {
    static var paris: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        c.locale = Locale(identifier: "fr_FR")
        return c
    }
}

func parisDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    Calendar.paris.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func day(_ y: Int, _ m: Int, _ d: Int) -> LocalDay { LocalDay(year: y, month: m, day: d) }

func hm(_ date: Date) -> String {
    let c = Calendar.paris.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour!, c.minute!)
}
