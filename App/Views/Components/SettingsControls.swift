import SwiftUI

struct MinutesPicker: View {
    let title: String
    let minutes: Int
    let onChange: (Int) -> Void

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                onChange((c.hour ?? 0) * 60 + (c.minute ?? 0))
            }), displayedComponents: .hourAndMinute)
    }
}

/// Rest-day chips, Monday first. Weekdays use Calendar numbering (1 = Sunday).
struct WeekdayToggles: View {
    let selection: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        let calendar = Calendar.current
        HStack(spacing: 6) {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                let on = selection.contains(weekday)
                Button { onToggle(weekday) } label: {
                    Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Theme.chalk : Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(on ? Theme.ground : Theme.chalk2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
