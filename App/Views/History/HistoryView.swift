import SwiftUI
import GrooveKit

struct HistoryView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @State private var monthOffset = 0

    var body: some View {
        let _ = store.revision
        let calendar = store.calendar
        let today = LocalDay(.now, calendar: calendar)
        let shown = calendar.date(byAdding: .month, value: monthOffset, to: today.date(minutesFromMidnight: 12 * 60, calendar: calendar))!
        let ym = calendar.dateComponents([.year, .month], from: shown)
        let statuses = store.dayStatuses(through: today, settings: settingsStore.settings)
        let volume = store.weeklyVolume(containing: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel(tr("history.previousMonth"))
                        Spacer()
                        Text(shown.formatted(.dateTime.month(.wide).year())).font(.headline).foregroundStyle(Theme.chalk)
                        Spacer()
                        Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(monthOffset >= 0)
                            .accessibilityLabel(tr("history.nextMonth"))
                    }
                    grid(year: ym.year!, month: ym.month!, statuses: statuses, today: today)
                    legend
                    Text(tr("history.record", StreakRules.longestStreak(statuses: statuses, calendar: calendar)))
                        .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.chalk2)
                    week(volume)
                }
                .padding(16)
            }
            .background(Theme.ground)
            .navigationTitle(tr("tab.history"))
        }
    }

    private func grid(year: Int, month: Int, statuses: [LocalDay: DayStatus], today: LocalDay) -> some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                Text(symbols[weekday - 1]).font(.caption2.weight(.semibold)).foregroundStyle(Theme.chalk3)
            }
            ForEach(Array(MonthGrid.cells(year: year, month: month, calendar: store.calendar).enumerated()), id: \.offset) { _, day in
                if let day {
                    cell(day, status: day > today ? nil : statuses[day], isToday: day == today)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func cell(_ day: LocalDay, status: DayStatus?, isToday: Bool) -> some View {
        let fill: Color
        switch status {
        case .complete: fill = Theme.chalk
        case .partial: fill = Theme.chalk.opacity(0.45)
        case .missed: fill = Theme.raised
        default: fill = .clear
        }
        return RoundedRectangle(cornerRadius: 8)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Text(verbatim: "\(day.day)")
                    .font(.caption.weight(status == .complete || isToday ? .bold : .regular)).monospacedDigit()
                    .foregroundStyle(status == .complete ? Theme.ground : Theme.chalk2)
            }
            .overlay {
                if status == .rest {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                if isToday { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.berry, lineWidth: 2) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: day, status: status, isToday: isToday))
    }

    private func accessibilityLabel(for day: LocalDay, status: DayStatus?, isToday: Bool) -> String {
        var dateText = day.date(minutesFromMidnight: 12 * 60, calendar: store.calendar)
            .formatted(.dateTime.day().month(.wide))
        if isToday { dateText += ", \(tr("history.today"))" }
        guard let word = legendWord(for: status) else { return dateText }
        return "\(dateText), \(word)"
    }

    private func legendWord(for status: DayStatus?) -> String? {
        guard let status else { return nil }
        switch status {
        case .complete: return tr("history.legend.complete")
        case .partial: return tr("history.legend.partial")
        case .rest: return tr("history.legend.rest")
        case .missed: return tr("history.legend.missed")
        case .none: return nil
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(Theme.chalk, tr("history.legend.complete"))
            legendItem(Theme.chalk.opacity(0.45), tr("history.legend.partial"))
            legendItem(.clear, tr("history.legend.rest"), dashed: true)
            legendItem(Theme.raised, tr("history.legend.missed"))
        }
        .font(.caption2)
        .foregroundStyle(Theme.chalk3)
    }

    private func legendItem(_ color: Color, _ label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
                .overlay { if dashed { RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.chalk3, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) } }
            Text(label)
        }
    }

    private func week(_ volume: [(exercise: Exercise, total: Int)]) -> some View {
        let top = max(1, volume.first?.total ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("history.week")).font(.caption).foregroundStyle(Theme.chalk3)
            if volume.isEmpty {
                Text(tr("history.weekEmpty")).font(.subheadline).foregroundStyle(Theme.chalk2)
            }
            ForEach(volume, id: \.exercise.id) { entry in
                HStack(spacing: 8) {
                    Text(entry.exercise.displayName()).font(.caption).foregroundStyle(Theme.chalk).frame(width: 110, alignment: .leading)
                    Capsule().fill(Theme.raised).frame(height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.chalk2)
                                .scaleEffect(x: CGFloat(entry.total) / CGFloat(top), y: 1, anchor: .leading)
                        }
                    Text(verbatim: entry.exercise.unit == .seconds ? "\(entry.total) \(tr("unit.seconds"))" : "\(entry.total)")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.chalk3)
                }
            }
        }
        .card()
    }
}
