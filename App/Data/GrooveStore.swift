import Foundation
import Observation
import SwiftData
import GrooveKit

enum DeletionResult: Equatable { case deleted, archived }
enum ExerciseNameError: Error, Equatable { case empty, tooLong, duplicate }

@MainActor @Observable
final class GrooveStore {
    static let modelTypes: [any PersistentModel.Type] = [
        Exercise.self, Program.self, MaxTest.self, SetLog.self, SkippedBlock.self, DayTarget.self,
    ]

    @ObservationIgnored let context: ModelContext
    @ObservationIgnored let calendar: Calendar
    /// Bumped on every write so views re-read.
    private(set) var revision = 0

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - Reads

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    func exercises(includeArchived: Bool = false) -> [Exercise] {
        let all = fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.createdAt)]))
        return includeArchived ? all : all.filter { !$0.isArchived }
    }

    func exercise(id: UUID) -> Exercise? {
        fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first
    }

    func programs(activeOnly: Bool = true) -> [Program] {
        let all = fetch(FetchDescriptor<Program>(sortBy: [SortDescriptor(\.position)]))
        return activeOnly ? all.filter(\.isActive) : all
    }

    func program(exerciseId: UUID) -> Program? {
        fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.exerciseId == exerciseId })).first
    }

    func setLogs(on day: LocalDay) -> [SetLog] {
        let key = day.key
        return fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.dayKey == key }, sortBy: [SortDescriptor(\.date)]))
    }

    func doneCounts(on day: LocalDay) -> [UUID: Int] {
        setLogs(on: day).reduce(into: [:]) { $0[$1.exerciseId, default: 0] += 1 }
    }

    func skippedBlocks(on day: LocalDay) -> [SkippedBlock] {
        let key = day.key
        return fetch(FetchDescriptor<SkippedBlock>(predicate: #Predicate { $0.dayKey == key }))
    }

    func maxTests(exerciseId: UUID) -> [MaxTest] {
        fetch(FetchDescriptor<MaxTest>(predicate: #Predicate { $0.exerciseId == exerciseId }, sortBy: [SortDescriptor(\.date)]))
    }

    func hasHistory(_ exercise: Exercise) -> Bool {
        let id = exercise.id
        let logs = (try? context.fetchCount(FetchDescriptor<SetLog>(predicate: #Predicate { $0.exerciseId == id }))) ?? 0
        return logs > 0 || !maxTests(exerciseId: id).isEmpty
    }

    func scheduleInput(now: Date, settings: GrooveSettings) -> ScheduleInput {
        let today = LocalDay(now, calendar: calendar)
        let logs = setLogs(on: today)
        let skipped = skippedBlocks(on: today)
        let handled = Set(logs.compactMap(\.blockId)).union(skipped.map(\.blockId))

        var lastIds: Set<UUID> = []
        let lastLog = logs.filter { $0.blockId != nil }.max { $0.date < $1.date }
        let lastSkip = skipped.max { $0.date < $1.date }
        if let lastLog, lastLog.date >= (lastSkip?.date ?? .distantPast) {
            lastIds = Set(logs.filter { $0.blockId == lastLog.blockId }.map(\.exerciseId))
        } else if let lastSkip {
            lastIds = Set(lastSkip.exerciseIds)
        }

        let exercises = programs().map {
            ScheduleExercise(id: $0.exerciseId, order: $0.position, dailySets: $0.dailySets, reps: $0.workingReps)
        }
        return ScheduleInput(now: now, settings: settings, exercises: exercises, doneToday: doneCounts(on: today),
                             handledBlockIds: handled, lastHandledExercises: lastIds)
    }

    func dayStatuses(through today: LocalDay, settings: GrooveSettings) -> [LocalDay: DayStatus] {
        let targets = fetch(FetchDescriptor<DayTarget>())
        let logs = fetch(FetchDescriptor<SetLog>())
        guard let first = (targets.map(\.dayKey) + logs.map(\.dayKey)).compactMap(LocalDay.init(key:)).min() else {
            return [:]
        }
        let targetByDay = Dictionary(targets.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
        var done: [String: [UUID: Int]] = [:]
        for log in logs { done[log.dayKey, default: [:]][log.exerciseId, default: 0] += 1 }

        var result: [LocalDay: DayStatus] = [:]
        var cursor = first
        while cursor <= today {
            let doneThatDay = done[cursor.key] ?? [:]
            if let target = targetByDay[cursor.key] {
                result[cursor] = StreakRules.status(targets: target.targets, done: doneThatDay, isRestDay: target.isRestDay)
            } else if settings.isRestDay(cursor, calendar: calendar) {
                result[cursor] = .rest
            } else {
                result[cursor] = doneThatDay.isEmpty ? .missed : .partial
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return result
    }

    /// Reps (or seconds) per exercise from Monday to Sunday of the week containing `day`.
    func weeklyVolume(containing day: LocalDay) -> [(exercise: Exercise, total: Int)] {
        let back = (day.weekday(calendar: calendar) + 5) % 7
        let monday = day.adding(days: -back, calendar: calendar)
        var totals: [UUID: Int] = [:]
        for offset in 0..<7 {
            for log in setLogs(on: monday.adding(days: offset, calendar: calendar)) {
                totals[log.exerciseId, default: 0] += log.reps
            }
        }
        return totals.compactMap { id, total in exercise(id: id).map { (exercise: $0, total: total) } }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Exercises

    func seedBuiltinsIfNeeded() {
        let existing = Set(exercises(includeArchived: true).compactMap(\.builtinKey))
        for (index, builtin) in ExerciseCatalog.builtins.enumerated() where !existing.contains(builtin.key) {
            // Epoch-based dates keep built-ins first and in catalog order.
            context.insert(Exercise(builtinKey: builtin.key, unit: builtin.unit, perSide: builtin.perSide,
                                    createdAt: Date(timeIntervalSince1970: Double(index))))
        }
        save()
    }

    private func validated(_ name: String, excluding: Exercise?) throws -> String {
        let names = exercises().filter { $0.id != excluding?.id }.map { $0.displayName() }
        switch ExerciseNameValidator.validate(name, existingNames: names) {
        case .ok(let clean): return clean
        case .empty: throw ExerciseNameError.empty
        case .tooLong: throw ExerciseNameError.tooLong
        case .duplicate: throw ExerciseNameError.duplicate
        }
    }

    @discardableResult
    func createCustomExercise(name: String, unit: ExerciseUnit, perSide: Bool) throws -> Exercise {
        let exercise = Exercise(customName: try validated(name, excluding: nil), unit: unit, perSide: perSide)
        context.insert(exercise)
        save()
        return exercise
    }

    func updateCustomExercise(_ exercise: Exercise, name: String, unit: ExerciseUnit, perSide: Bool) throws {
        guard exercise.isCustom else { return }
        exercise.customName = try validated(name, excluding: exercise)
        exercise.perSide = perSide
        if canChangeUnit(exercise) { exercise.unit = unit }
        save()
    }

    func canChangeUnit(_ exercise: Exercise) -> Bool { !hasHistory(exercise) }

    func deleteOrArchive(_ exercise: Exercise) -> DeletionResult {
        let program = program(exerciseId: exercise.id)
        guard exercise.isCustom else {
            // Built-ins stay in the library forever: seedBuiltinsIfNeeded() would otherwise
            // recreate a deleted one with a new id, orphaning existing references.
            program?.isActive = false
            save()
            return .archived
        }
        if hasHistory(exercise) {
            exercise.isArchived = true
            program?.isActive = false
            save()
            return .archived
        }
        if let program { context.delete(program) }
        context.delete(exercise)
        save()
        return .deleted
    }

    // MARK: - Programs

    private var nextPosition: Int { (programs(activeOnly: false).map(\.position).max() ?? -1) + 1 }

    @discardableResult
    func activate(_ exercise: Exercise, maxValue: Int, settings: GrooveSettings, at date: Date = .now) -> Program {
        let program: Program
        if let existing = self.program(exerciseId: exercise.id) {
            if !existing.isActive { existing.position = nextPosition }
            existing.isActive = true
            existing.maxValue = maxValue
            existing.lastTestDate = date
            program = existing
        } else {
            program = Program(exerciseId: exercise.id, position: nextPosition, maxValue: maxValue,
                              workPercent: settings.defaultWorkPercent, lastTestDate: date)
            context.insert(program)
        }
        context.insert(MaxTest(exerciseId: exercise.id, date: date, value: maxValue))
        save()
        return program
    }

    func setActive(_ program: Program, _ active: Bool) {
        if active && !program.isActive { program.position = nextPosition }
        program.isActive = active
        save()
    }

    func moveActivePrograms(from source: IndexSet, to destination: Int) {
        var list = programs()
        list.move(fromOffsets: source, toOffset: destination)
        for (index, program) in list.enumerated() { program.position = index }
        save()
    }

    func update(_ program: Program, _ change: (Program) -> Void) {
        change(program)
        save()
    }

    func recordMaxTest(_ program: Program, value: Int, at date: Date = .now) -> ProgramRules.RetestOutcome {
        let outcome = ProgramRules.retestOutcome(newMax: value, workPercent: program.workPercent, manualReps: program.manualReps)
        program.maxValue = value
        program.lastTestDate = date
        context.insert(MaxTest(exerciseId: program.exerciseId, date: date, value: value))
        save()
        return outcome
    }

    func useRecalculatedReps(_ program: Program) {
        program.manualReps = nil
        save()
    }

    // MARK: - Logging

    private func dayKey(forBlock blockId: String, fallback date: Date) -> String {
        let prefix = String(blockId.prefix(10))
        return LocalDay(key: prefix) != nil ? prefix : LocalDay(date, calendar: calendar).key
    }

    /// Logs every known, non-archived exercise of the block. Returns false if nothing was logged
    /// (block already logged, or no known exercise).
    @discardableResult
    func logBlock(_ payload: BlockPayload, at date: Date) -> Bool {
        let key = dayKey(forBlock: payload.blockId, fallback: date)
        let sameDay = fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.dayKey == key }))
        guard !sameDay.contains(where: { $0.blockId == payload.blockId }) else { return false }
        var logged = false
        for item in payload.items {
            guard let exercise = exercise(id: item.exerciseId), !exercise.isArchived else { continue }
            context.insert(SetLog(exerciseId: item.exerciseId, date: date, dayKey: key, reps: item.reps, blockId: payload.blockId))
            logged = true
        }
        if logged { save() }
        return logged
    }

    func skipBlock(_ payload: BlockPayload, at date: Date) {
        let id = payload.blockId
        let exists = ((try? context.fetchCount(FetchDescriptor<SkippedBlock>(predicate: #Predicate { $0.blockId == id }))) ?? 0) > 0
        guard !exists else { return }
        context.insert(SkippedBlock(blockId: id, date: date, dayKey: dayKey(forBlock: id, fallback: date),
                                    exerciseIds: payload.items.map(\.exerciseId)))
        save()
    }

    func undoBlock(blockId: String) {
        let key = dayKey(forBlock: blockId, fallback: .now)
        for log in fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.dayKey == key })) where log.blockId == blockId {
            context.delete(log)
        }
        save()
    }

    @discardableResult
    func logSet(exerciseId: UUID, reps: Int, at date: Date) -> UUID {
        let log = SetLog(exerciseId: exerciseId, date: date, dayKey: LocalDay(date, calendar: calendar).key,
                         reps: reps, blockId: nil)
        context.insert(log)
        save()
        return log.id
    }

    /// No-op if the set was already removed (e.g. undo tapped twice).
    func undoSet(id: UUID) {
        if let log = fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.id == id })).first {
            context.delete(log)
        }
        save()
    }

    func refreshDayTarget(for day: LocalDay, settings: GrooveSettings) {
        let key = day.key
        let targets = Dictionary(programs().map { ($0.exerciseId, $0.dailySets) }, uniquingKeysWith: { a, _ in a })
        let isRest = settings.isRestDay(day, calendar: calendar)
        if let existing = fetch(FetchDescriptor<DayTarget>(predicate: #Predicate { $0.dayKey == key })).first {
            existing.targets = targets
            existing.isRestDay = isRest
        } else {
            context.insert(DayTarget(dayKey: key, isRestDay: isRest, targets: targets))
        }
        save()
    }

    /// Called when the app comes back to the foreground or the day changes.
    func noteExternalChanges() { revision += 1 }

    private func save() {
        try? context.save()
        revision += 1
    }
}
