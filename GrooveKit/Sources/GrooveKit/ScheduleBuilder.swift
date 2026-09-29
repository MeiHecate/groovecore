import Foundation

public struct ScheduleExercise: Equatable, Sendable {
    public let id: UUID
    public let order: Int
    public let dailySets: Int
    public let reps: Int
    public init(id: UUID, order: Int, dailySets: Int, reps: Int) {
        self.id = id
        self.order = order
        self.dailySets = dailySets
        self.reps = reps
    }
}

public struct ScheduleInput: Sendable {
    public var now: Date
    public var settings: GrooveSettings
    public var exercises: [ScheduleExercise]
    public var doneToday: [UUID: Int]
    public var handledBlockIds: Set<String>
    public var lastHandledExercises: Set<UUID>

    public init(now: Date, settings: GrooveSettings, exercises: [ScheduleExercise], doneToday: [UUID: Int],
                handledBlockIds: Set<String>, lastHandledExercises: Set<UUID>) {
        self.now = now
        self.settings = settings
        self.exercises = exercises
        self.doneToday = doneToday
        self.handledBlockIds = handledBlockIds
        self.lastHandledExercises = lastHandledExercises
    }
}

public enum ScheduleBuilder {
    public static let maxNotifications = 60
    public static let maxDays = 14

    public static func todayPlan(_ input: ScheduleInput, calendar: Calendar) -> DayPlan {
        let today = LocalDay(input.now, calendar: calendar)
        let slots = SlotBuilder.slots(on: today, settings: input.settings, calendar: calendar).filter {
            $0 > input.now && !input.handledBlockIds.contains(BlockPlanner.blockId(for: $0, calendar: calendar))
        }
        let exercises = input.exercises.map {
            PlannerExercise(id: $0.id, order: $0.order,
                            remainingSets: max(0, $0.dailySets - input.doneToday[$0.id, default: 0]), reps: $0.reps)
        }
        return BlockPlanner.plan(slots: slots, exercises: exercises, maxBlockSize: input.settings.maxBlockSize,
                                 previousBlock: input.lastHandledExercises, calendar: calendar)
    }

    static func fullDayPlan(day: LocalDay, exercises: [ScheduleExercise], settings: GrooveSettings, calendar: Calendar) -> DayPlan {
        let slots = SlotBuilder.slots(on: day, settings: settings, calendar: calendar)
        let planner = exercises.map { PlannerExercise(id: $0.id, order: $0.order, remainingSets: $0.dailySets, reps: $0.reps) }
        return BlockPlanner.plan(slots: slots, exercises: planner, maxBlockSize: settings.maxBlockSize,
                                 previousBlock: [], calendar: calendar)
    }

    public static func upcomingBlocks(_ input: ScheduleInput, calendar: Calendar) -> [PlannedBlock] {
        var result = todayPlan(input, calendar: calendar).blocks
        let today = LocalDay(input.now, calendar: calendar)
        var offset = 1
        while result.count < maxNotifications && offset < maxDays {
            let day = today.adding(days: offset, calendar: calendar)
            result += fullDayPlan(day: day, exercises: input.exercises, settings: input.settings, calendar: calendar).blocks
            offset += 1
        }
        return Array(result.prefix(maxNotifications))
    }

    /// Sets that don't fit in a full working day with these settings (rest days ignored).
    public static func capacityOverflow(exercises: [ScheduleExercise], settings: GrooveSettings,
                                        referenceDay: LocalDay, calendar: Calendar) -> Int {
        var workday = settings
        workday.restWeekdays = []
        return fullDayPlan(day: referenceDay, exercises: exercises, settings: workday, calendar: calendar).overflowSets
    }
}
