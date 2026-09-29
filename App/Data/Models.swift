import Foundation
import SwiftData
import GrooveKit

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var builtinKey: String?
    var customName: String?
    var unitRaw: String
    var perSide: Bool
    var isArchived: Bool
    var createdAt: Date

    init(id: UUID = UUID(), builtinKey: String? = nil, customName: String? = nil,
         unit: ExerciseUnit, perSide: Bool, createdAt: Date = .now) {
        self.id = id
        self.builtinKey = builtinKey
        self.customName = customName
        self.unitRaw = unit.rawValue
        self.perSide = perSide
        self.isArchived = false
        self.createdAt = createdAt
    }

    var unit: ExerciseUnit {
        get { ExerciseUnit(rawValue: unitRaw) ?? .reps }
        set { unitRaw = newValue.rawValue }
    }

    var isCustom: Bool { builtinKey == nil }

    func displayName(locale: Locale? = nil) -> String {
        guard let builtinKey else { return customName ?? "" }
        let key = "exercise." + builtinKey
        if let locale { return tr(key, locale: locale) }
        return tr(key)
    }
}

@Model
final class Program {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var isActive: Bool
    var position: Int
    var maxValue: Int
    var workPercent: Int
    var manualReps: Int?
    var dailySets: Int
    var retestIntervalDays: Int
    var lastTestDate: Date

    init(id: UUID = UUID(), exerciseId: UUID, position: Int, maxValue: Int, workPercent: Int,
         dailySets: Int = 8, retestIntervalDays: Int = 10, lastTestDate: Date) {
        self.id = id
        self.exerciseId = exerciseId
        self.isActive = true
        self.position = position
        self.maxValue = maxValue
        self.workPercent = workPercent
        self.manualReps = nil
        self.dailySets = dailySets
        self.retestIntervalDays = retestIntervalDays
        self.lastTestDate = lastTestDate
    }

    var workingReps: Int {
        ProgramRules.workingReps(maxValue: maxValue, workPercent: workPercent, manualReps: manualReps)
    }
}

@Model
final class MaxTest {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var date: Date
    var value: Int

    init(id: UUID = UUID(), exerciseId: UUID, date: Date, value: Int) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.value = value
    }
}

@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var date: Date
    var dayKey: String
    var reps: Int
    var blockId: String?

    init(id: UUID = UUID(), exerciseId: UUID, date: Date, dayKey: String, reps: Int, blockId: String?) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.dayKey = dayKey
        self.reps = reps
        self.blockId = blockId
    }
}

@Model
final class SkippedBlock {
    @Attribute(.unique) var blockId: String
    var date: Date
    var dayKey: String
    var exerciseIds: [UUID]

    init(blockId: String, date: Date, dayKey: String, exerciseIds: [UUID]) {
        self.blockId = blockId
        self.date = date
        self.dayKey = dayKey
        self.exerciseIds = exerciseIds
    }
}

@Model
final class DayTarget {
    @Attribute(.unique) var dayKey: String
    var isRestDay: Bool
    var targetsJSON: Data

    init(dayKey: String, isRestDay: Bool, targets: [UUID: Int]) {
        self.dayKey = dayKey
        self.isRestDay = isRestDay
        self.targetsJSON = Data()
        self.targets = targets
    }

    var targets: [UUID: Int] {
        get {
            let raw = (try? JSONDecoder().decode([String: Int].self, from: targetsJSON)) ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value) })
            targetsJSON = (try? JSONEncoder().encode(raw)) ?? Data()
        }
    }
}
