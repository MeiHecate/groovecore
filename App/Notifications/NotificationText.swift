import Foundation
import GrooveKit

enum NotificationText {
    struct Item: Equatable {
        let name: String
        let reps: Int
        let unit: ExerciseUnit
        let perSide: Bool
    }

    static func title(for date: Date, locale: Locale) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return tr("notif.title", locale: locale, time)
    }

    static func item(_ item: Item, locale: Locale) -> String {
        let key: String
        switch (item.unit, item.perSide) {
        case (.reps, false): key = "notif.item.reps"
        case (.reps, true): key = "notif.item.perSide"
        case (.seconds, false): key = "notif.item.seconds"
        case (.seconds, true): key = "notif.item.secondsPerSide"
        }
        return tr(key, locale: locale, item.name, item.reps)
    }

    static func body(_ items: [Item], locale: Locale) -> String {
        items.map { item($0, locale: locale) }.joined(separator: " · ")
    }

    /// Items of a block whose exercise still exists and is not archived.
    @MainActor
    static func items(for block: PlannedBlock, store: GrooveStore, locale: Locale) -> [Item] {
        block.items.compactMap { planned in
            guard let exercise = store.exercise(id: planned.exerciseId), !exercise.isArchived else { return nil }
            return Item(name: exercise.displayName(locale: locale), reps: planned.reps, unit: exercise.unit, perSide: exercise.perSide)
        }
    }
}
