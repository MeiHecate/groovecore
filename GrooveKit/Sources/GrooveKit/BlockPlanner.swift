import Foundation

public struct PlannedItem: Codable, Equatable, Hashable, Sendable {
    public let exerciseId: UUID
    public let reps: Int
    public init(exerciseId: UUID, reps: Int) {
        self.exerciseId = exerciseId
        self.reps = reps
    }
}

public struct PlannedBlock: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let date: Date
    public let items: [PlannedItem]
    public init(id: String, date: Date, items: [PlannedItem]) {
        self.id = id
        self.date = date
        self.items = items
    }
}

public struct PlannerExercise: Equatable, Sendable {
    public let id: UUID
    public let order: Int
    public let remainingSets: Int
    public let reps: Int
    public init(id: UUID, order: Int, remainingSets: Int, reps: Int) {
        self.id = id
        self.order = order
        self.remainingSets = remainingSets
        self.reps = reps
    }
}

public struct DayPlan: Equatable, Sendable {
    public let blocks: [PlannedBlock]
    public let overflowSets: Int
    public init(blocks: [PlannedBlock], overflowSets: Int) {
        self.blocks = blocks
        self.overflowSets = overflowSets
    }
}

public enum BlockPlanner {
    private struct Entry {
        let ideal: Int
        let order: Int
        let id: UUID
        let reps: Int
    }

    private static let golden = 0.6180339887498949

    public static func blockId(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02d-%02d%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!)
    }

    public static func plan(
        slots: [Date],
        exercises: [PlannerExercise],
        maxBlockSize: Int,
        previousBlock: Set<UUID>,
        calendar: Calendar
    ) -> DayPlan {
        let active = exercises.filter { $0.remainingSets > 0 }.sorted { $0.order < $1.order }
        let total = active.reduce(0) { $0 + $1.remainingSets }
        let slotCount = slots.count
        guard slotCount > 0, total > 0 else { return DayPlan(blocks: [], overflowSets: total) }
        let capacity = max(1, maxBlockSize)

        var entries: [Entry] = []
        for (index, exercise) in active.enumerated() {
            let n = exercise.remainingSets
            let skipFirst = previousBlock.contains(exercise.id) && slotCount > 1 && n <= slotCount - 1
            let start = skipFirst ? 1 : 0
            let span = slotCount - start
            let phase = (Double(index) * golden).truncatingRemainder(dividingBy: 1)
            for k in 0..<n {
                let offset = Int((Double(k) + phase) * Double(span) / Double(n))
                entries.append(Entry(ideal: start + min(span - 1, offset), order: exercise.order, id: exercise.id, reps: exercise.reps))
            }
        }

        var pending: [Entry] = []
        var blocks: [PlannedBlock] = []
        var lastIds = previousBlock
        for (slotIndex, date) in slots.enumerated() {
            pending += entries.filter { $0.ideal == slotIndex }
            pending.sort {
                if $0.ideal != $1.ideal { return $0.ideal < $1.ideal }
                let p0 = lastIds.contains($0.id), p1 = lastIds.contains($1.id)
                if p0 != p1 { return !p0 }
                return $0.order < $1.order
            }
            var chosen: [Entry] = []
            var chosenIds: Set<UUID> = []
            var rest: [Entry] = []
            for entry in pending {
                if chosen.count < capacity, !chosenIds.contains(entry.id) {
                    chosen.append(entry)
                    chosenIds.insert(entry.id)
                } else {
                    rest.append(entry)
                }
            }
            pending = rest
            lastIds = chosenIds
            guard !chosen.isEmpty else { continue }
            let items = chosen.sorted { $0.order < $1.order }.map { PlannedItem(exerciseId: $0.id, reps: $0.reps) }
            blocks.append(PlannedBlock(id: blockId(for: date, calendar: calendar), date: date, items: items))
        }
        return DayPlan(blocks: blocks, overflowSets: pending.count)
    }
}
