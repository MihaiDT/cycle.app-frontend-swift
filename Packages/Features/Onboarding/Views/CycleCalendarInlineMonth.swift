import SwiftUI

// MARK: - Inline Month View

struct InlineMonthView: View {
    let month: Date
    let periodStart: Date?
    let periodEnd: Date?
    let allPeriodDates: Set<Date>
    let currentSelectionDates: Set<Date>
    let savedPeriods: [InlinePeriodCalendarPage.Period]
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        // Pad to 42 cells (6 rows) for consistent height
        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private func isInPeriod(_ date: Date) -> Bool {
        allPeriodDates.contains(calendar.startOfDay(for: date))
    }

    private func isCurrentSelection(_ date: Date) -> Bool {
        currentSelectionDates.contains(calendar.startOfDay(for: date))
    }

    private func isStartDate(_ date: Date) -> Bool {
        if let start = periodStart, calendar.isDate(date, inSameDayAs: start) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.start) {
                return true
            }
        }
        return false
    }

    private func isEndDate(_ date: Date) -> Bool {
        if let end = periodEnd, calendar.isDate(date, inSameDayAs: end) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.end) {
                return true
            }
        }
        return false
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        date > Date()
    }

    var body: some View {
        VStack(spacing: 12) {
            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(height: 24)
                        .accessibilityHidden(true)
                }
            }

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        InlineDayCell(
                            date: date,
                            isInPeriod: isInPeriod(date),
                            isCurrentSelection: isCurrentSelection(date),
                            isStartDate: isStartDate(date),
                            isEndDate: isEndDate(date),
                            isToday: isToday(date),
                            isFuture: isFuture(date),
                            onTap: { onDayTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }
}

struct InlineDayCell: View {
    let date: Date
    let isInPeriod: Bool
    let isCurrentSelection: Bool
    let isStartDate: Bool
    let isEndDate: Bool
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        var label = formatter.string(from: date)
        if isToday { label = "Today, " + label }
        if isInPeriod { label += ". Period day" }
        if isStartDate { label += ". Period start" }
        if isEndDate { label += ". Period end" }
        if isFuture { label += ". Future date, disabled" }
        return label
    }

    var body: some View {
        Button(action: {
            if !isFuture {
                onTap()
            }
        }) {
            VStack(spacing: 2) {
                ZStack {
                    // Period highlight background
                    if isInPeriod {
                        if isStartDate || isEndDate {
                            Circle()
                                .fill(isCurrentSelection ? DesignColors.accentWarm : DesignColors.roseTaupe)
                        } else {
                            // Middle days - use circles
                            Circle()
                                .fill(
                                    isCurrentSelection
                                        ? DesignColors.accentWarm.opacity(0.4) : DesignColors.roseTaupeLight
                                )
                        }
                    } else if isToday {
                        Circle()
                            .strokeBorder(DesignColors.accentWarm, lineWidth: 1.5)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.raleway(isStartDate || isEndDate ? "Bold" : "Medium", size: 16, relativeTo: .body))
                        .foregroundColor(dayTextColor)
                }
                .frame(width: 40, height: 40)

                // "Today" label
                if isToday {
                    Text("today")
                        .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                        .foregroundColor(DesignColors.accentWarm)
                }
            }
        }
        .disabled(isFuture)
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel)
        .accessibilityAddTraits(isInPeriod ? [.isSelected, .isButton] : [.isButton])
    }

    private var dayTextColor: Color {
        if isFuture {
            return DesignColors.text.opacity(0.3)
        } else if isStartDate || isEndDate {
            return .white
        } else if isInPeriod {
            return DesignColors.text
        } else {
            return DesignColors.text
        }
    }
}
