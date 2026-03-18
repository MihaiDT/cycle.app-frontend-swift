import SwiftUI

// MARK: - Glass Week Calendar

/// Week calendar strip with paged swipe, full-width, no box.
public struct GlassWeekCalendar: View {
    public let cycleDay: Int
    public let cycleLength: Int
    public let cycleStartDate: Date
    public let bleedingDays: Int
    public let predictedPeriodStart: Date?
    @Binding public var selectedDay: Int?
    public var isCompact: Bool
    public var onExpandTapped: (() -> Void)?

    @State private var weekOffset: Int = 0

    private let calendar = Calendar.current
    private let weekRange = -12...6

    public init(
        cycleDay: Int,
        cycleLength: Int,
        cycleStartDate: Date,
        bleedingDays: Int = 5,
        predictedPeriodStart: Date? = nil,
        selectedDay: Binding<Int?>,
        isCompact: Bool = false,
        onExpandTapped: (() -> Void)? = nil
    ) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.cycleStartDate = cycleStartDate
        self.bleedingDays = bleedingDays
        self.predictedPeriodStart = predictedPeriodStart
        self._selectedDay = selectedDay
        self.isCompact = isCompact
        self.onExpandTapped = onExpandTapped
    }

    private var displayDay: Int {
        selectedDay ?? cycleDay
    }

    private func weekDates(for offset: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        // Center today (3 days before, today, 3 days after)
        let centerDate = calendar.date(byAdding: .day, value: offset * 7, to: today) ?? today
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: centerDate) }
    }

    private func cycleDayFor(date: Date) -> Int? {
        let daysDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: cycleStartDate), to: calendar.startOfDay(for: date)).day ?? 0
        let day = daysDiff + 1
        guard day >= 1 && day <= cycleLength else { return nil }
        return day
    }

    private func phaseForDay(_ day: Int) -> CyclePhase {
        let ovulationDay = cycleLength - 14
        switch day {
        case 1...bleedingDays: return .menstrual
        case (bleedingDays + 1)...(ovulationDay - 2): return .follicular
        case (ovulationDay - 1)...(ovulationDay + 1): return .ovulatory
        default: return .luteal
        }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isPredictedPeriod(_ date: Date) -> Bool {
        guard let start = predictedPeriodStart else { return false }
        let d = calendar.startOfDay(for: date)
        let s = calendar.startOfDay(for: start)
        let diff = calendar.dateComponents([.day], from: s, to: d).day ?? -1
        return diff >= 0 && diff < bleedingDays
    }

    private var weekdayLabels: [String] {
        // Labels match centered layout: 3 days before today, today, 3 days after
        let today = Date()
        return (-3...3).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let idx = calendar.component(.weekday, from: date) - 1
            return String(calendar.shortWeekdaySymbols[idx].prefix(3))
        }
    }

    private var weekMonthLabel: String {
        let dates = weekDates(for: weekOffset)
        guard let first = dates.first, let last = dates.last else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)
        if firstMonth == lastMonth {
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: first)
        } else {
            fmt.dateFormat = "MMM"
            let m1 = fmt.string(from: first)
            let m2 = fmt.string(from: last)
            fmt.dateFormat = "yyyy"
            return "\(m1) – \(m2) \(fmt.string(from: last))"
        }
    }

    public var body: some View {
        VStack(spacing: isCompact ? 2 : 6) {
            if !isCompact {
                // Month label
                Text(weekMonthLabel)
                    .font(.custom("Raleway-SemiBold", size: 13))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.none, value: weekOffset)

                // Weekday labels
                HStack(spacing: 0) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.custom("Raleway-Medium", size: 12))
                            .foregroundColor(DesignColors.textSecondary.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Paged week carousel
            TabView(selection: $weekOffset) {
                ForEach(weekRange, id: \.self) { offset in
                    weekRow(for: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: isCompact ? 38 : 62)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isCompact)
        .onChange(of: weekOffset) { _, newOffset in
            // Select the center day (index 3) of the new week
            let dates = weekDates(for: newOffset)
            guard dates.count == 7 else { return }
            let centerDate = dates[3]
            if let cd = cycleDayFor(date: centerDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDay = cd
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDay = nil
                }
            }
        }
    }

    // MARK: - Week Row

    private func weekRow(for offset: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(weekDates(for: offset), id: \.self) { date in
                let dayCycle = cycleDayFor(date: date)
                let isSelected = dayCycle != nil && dayCycle == displayDay
                let isTodayDate = isToday(date)

                dayCell(
                    date: date,
                    cycleDayNum: dayCycle,
                    isSelected: isSelected,
                    isToday: isTodayDate,
                    isPredicted: isPredictedPeriod(date)
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(date: Date, cycleDayNum: Int?, isSelected: Bool, isToday: Bool, isPredicted: Bool) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let phase = cycleDayNum.map { phaseForDay($0) }
        let highlighted = isSelected || isToday
        let isPeriodDay = phase == .menstrual
        let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())

        return VStack(spacing: 2) {
            ZStack {
                // Predicted period: dashed circle with light fill
                if isPredicted && !isPeriodDay && !isSelected {
                    Circle()
                        .fill(CyclePhase.menstrual.orbitColor.opacity(0.15))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                                .foregroundColor(CyclePhase.menstrual.orbitColor.opacity(0.45))
                        }
                }

                // Period day: solid past, dashed future
                if isPeriodDay && !isSelected {
                    if isFuture {
                        Circle()
                            .fill(CyclePhase.menstrual.orbitColor.opacity(0.25))
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                    )
                                    .foregroundColor(CyclePhase.menstrual.orbitColor.opacity(0.6))
                            }
                    } else {
                        Circle()
                            .fill(CyclePhase.menstrual.orbitColor.opacity(0.75))
                            .overlay {
                                if isToday {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                }
                            }
                    }
                }

                // Selected
                if isSelected {
                    Circle()
                        .fill(phase?.orbitColor ?? DesignColors.accent)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.05), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                }

                // Today (not selected, not period): dashed
                if isToday && !isSelected && !isPeriodDay {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundColor(DesignColors.accentWarm)
                }

                Text("\(dayNumber)")
                    .font(.custom(highlighted || isPeriodDay || isPredicted ? "Raleway-Bold" : "Raleway-SemiBold", size: isCompact ? 14 : 16))
                    .foregroundColor(
                        isSelected || (isPeriodDay && !isFuture)
                            ? .white
                            : isPredicted
                                ? CyclePhase.menstrual.orbitColor
                                : isToday
                                    ? DesignColors.text
                                    : cycleDayNum != nil
                                        ? DesignColors.text.opacity(0.75)
                                        : DesignColors.textPlaceholder.opacity(0.5)
                    )
            }
            .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)

            // Phase dot / Today label
            if !isCompact {
                if isToday {
                    Text("Today")
                        .font(.custom("Raleway-Bold", size: 8))
                        .foregroundColor(DesignColors.accentWarm)
                        .frame(height: 10)
                } else if let phase = phase {
                    Circle()
                        .fill(phase.orbitColor.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .frame(height: 10)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let cd = cycleDayNum else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedDay = cd == cycleDay ? nil : cd
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview("Glass Week Calendar") {
    ZStack {
        DesignColors.background
            .ignoresSafeArea()

        GlassWeekCalendar(
            cycleDay: 8,
            cycleLength: 28,
            cycleStartDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            bleedingDays: 5,
            predictedPeriodStart: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
            selectedDay: .constant(nil)
        )
        .padding(.horizontal, 20)
    }
}
