import Testing
@testable import GrooveKit

@Suite struct ExerciseCatalogTests {
    @Test func tenBuiltinsWithUniqueKeys() {
        let keys = ExerciseCatalog.builtins.map(\.key)
        #expect(keys == ["pullups", "chinups", "pushups", "diamondPushups", "dips",
                         "squats", "pistolSquat", "lunges", "plank", "hollowHold"])
        #expect(Set(keys).count == 10)
    }

    @Test func unitsAndSides() {
        let byKey = Dictionary(uniqueKeysWithValues: ExerciseCatalog.builtins.map { ($0.key, $0) })
        #expect(byKey["plank"]?.unit == .seconds)
        #expect(byKey["hollowHold"]?.unit == .seconds)
        #expect(byKey["pistolSquat"]?.perSide == true)
        #expect(byKey["lunges"]?.perSide == true)
        #expect(byKey["pullups"]?.unit == .reps)
        #expect(byKey["pullups"]?.perSide == false)
    }

    @Test func validation() {
        let existing = ["Tractions", "Pompes"]
        #expect(ExerciseNameValidator.validate("", existingNames: existing) == .empty)
        #expect(ExerciseNameValidator.validate("   ", existingNames: existing) == .empty)
        #expect(ExerciseNameValidator.validate(String(repeating: "a", count: 41), existingNames: existing) == .tooLong)
        #expect(ExerciseNameValidator.validate(String(repeating: "a", count: 40), existingNames: existing)
                == .ok(String(repeating: "a", count: 40)))
        #expect(ExerciseNameValidator.validate("tractions", existingNames: existing) == .duplicate)
        #expect(ExerciseNameValidator.validate("  POMPES ", existingNames: existing) == .duplicate)
        #expect(ExerciseNameValidator.validate("  Muscle-up ", existingNames: existing) == .ok("Muscle-up"))
    }
}
