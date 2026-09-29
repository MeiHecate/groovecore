import Foundation

public enum ExerciseUnit: String, Codable, Sendable, CaseIterable {
    case reps, seconds
}

public struct BuiltinExercise: Equatable, Sendable {
    public let key: String
    public let unit: ExerciseUnit
    public let perSide: Bool
    public init(key: String, unit: ExerciseUnit = .reps, perSide: Bool = false) {
        self.key = key
        self.unit = unit
        self.perSide = perSide
    }
}

public enum ExerciseCatalog {
    public static let builtins: [BuiltinExercise] = [
        BuiltinExercise(key: "pullups"),
        BuiltinExercise(key: "chinups"),
        BuiltinExercise(key: "pushups"),
        BuiltinExercise(key: "diamondPushups"),
        BuiltinExercise(key: "dips"),
        BuiltinExercise(key: "squats"),
        BuiltinExercise(key: "pistolSquat", perSide: true),
        BuiltinExercise(key: "lunges", perSide: true),
        BuiltinExercise(key: "plank", unit: .seconds),
        BuiltinExercise(key: "hollowHold", unit: .seconds),
    ]
}

public enum ExerciseNameValidation: Equatable, Sendable {
    case ok(String)
    case empty
    case tooLong
    case duplicate
}

public enum ExerciseNameValidator {
    public static let maxLength = 40

    public static func validate(_ name: String, existingNames: [String]) -> ExerciseNameValidation {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maxLength { return .tooLong }
        let lowered = trimmed.lowercased()
        if existingNames.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowered }) {
            return .duplicate
        }
        return .ok(trimmed)
    }
}
