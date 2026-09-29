import Foundation

public enum DayStatus: String, Codable, Sendable {
    case rest, complete, partial, missed, none
}

public enum StreakRules {
    public static func status(targets: [UUID: Int], done: [UUID: Int], isRestDay: Bool) -> DayStatus {
        if isRestDay { return .rest }
        let active = targets.filter { $0.value > 0 }
        if active.isEmpty { return .none }
        if active.allSatisfy({ done[$0.key, default: 0] >= $0.value }) { return .complete }
        return done.values.reduce(0, +) > 0 ? .partial : .missed
    }

    /// Complete days going back from yesterday, rest days skipped. Today adds one only if complete.
    public static func currentStreak(statuses: [LocalDay: DayStatus], today: LocalDay, calendar: Calendar) -> Int {
        guard let earliest = statuses.keys.min() else { return 0 }
        var count = statuses[today] == .complete ? 1 : 0
        var cursor = today.adding(days: -1, calendar: calendar)
        while cursor >= earliest {
            switch statuses[cursor] {
            case .complete: count += 1
            case .rest: break
            default: return count
            }
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        return count
    }

    public static func longestStreak(statuses: [LocalDay: DayStatus], calendar: Calendar) -> Int {
        guard let first = statuses.keys.min(), let last = statuses.keys.max() else { return 0 }
        var best = 0, run = 0, cursor = first
        while cursor <= last {
            switch statuses[cursor] {
            case .complete: run += 1; best = max(best, run)
            case .rest: break
            default: run = 0
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return best
    }
}
