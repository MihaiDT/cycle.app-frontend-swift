import SwiftUI

// MARK: - Mini Cycle Calendar

/// Full-width navigable week calendar strip (Mon-Sun).
/// Swipe between weeks via TabView paging. Shows period/fertile/phase indicators.
/// "TODAY" label above the current day. Month header appears when navigated away.
public struct MiniCycleCalendar: View {
    public let cycle: CycleContext
    @Binding public var selectedDate: Date?
    public var embedded: Bool

    @State private var currentWeekOffset: Int = 0

    private let cal = Calendar.current
    private let weekRange = -26...52

    public init(cycle: CycleContext, selectedDate: Binding<Date?>, embedded: Bool = false) {
        self.cycle = cycle
        self._selectedDate = selectedDate
        self.embedded = embedded
    }

    // MARK: - Week Date Computation

    /// Monday of the current calendar week
    private var thisMonday: Date {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysToMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysToMonday, to: today)!
    }

    /// The 7 dates (Mon-Sun) for a given week offset
    private func weekDates(for offset: Int) -> [Date] {
        let monday = cal.date(byAdding: .weekOfYear, value: offset, to: thisMonday)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Month header — always visible
            monthHeader

            // Paging week strip
            TabView(selection: $currentWeekOffset) {
                ForEach(weekRange, id: \.self) { offset in
                    weekRow(for: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 82)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.3))
                        .frame(height: 0.5)
                }
                .opacity(embedded ? 0 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentWeekOffset)
    }

    // MARK: - Month Header

    @ViewBuilder
    private var monthHeader: some View {
        let dates = weekDates(for: currentWeekOffset)

        ZStack {
            Text(monthLabel(for: dates))
                .font(.custom("Raleway-SemiBold", size: 13))
                .foregroundColor(DesignColors.textSecondary)

            if currentWeekOffset != 0 {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentWeekOffset = 0
                            selectedDate = nil
                        }
                    } label: {
                        Text("Today")
                            .font(.custom("Raleway-SemiBold", size: 12))
                            .foregroundColor(DesignColors.accentWarm)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func monthLabel(for dates: [Date]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let first = formatter.string(from: dates.first!)
        let last = formatter.string(from: dates.last!)
        if first == last { return first }
        let shortFmt = DateFormatter()
        shortFmt.dateFormat = "MMM"
        let yearFmt = DateFormatter()
        yearFmt.dateFormat = "yyyy"
        return "\(shortFmt.string(from: dates.first!)) – \(shortFmt.string(from: dates.last!)) \(yearFmt.string(from: dates.last!))"
    }

    // MARK: - Week Row

    private func weekRow(for offset: Int) -> some View {
        let dates = weekDates(for: offset)
        return HStack(spacing: 0) {
            ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                let isToday = cal.isDateInToday(date)
                let cycleDay = cycle.cycleDayNumber(for: date)
                let phase = cycle.phase(for: date)
                let isSelected = selectedDate != nil && cal.isDate(selectedDate!, inSameDayAs: date)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if isSelected {
                            selectedDate = nil
                        } else {
                            selectedDate = cal.startOfDay(for: date)
                        }
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dayCell(
                        date: date,
                        cycleDay: cycleDay,
                        phase: phase,
                        isToday: isToday,
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(
        date: Date,
        cycleDay: Int?,
        phase: CyclePhase?,
        isToday: Bool,
        isSelected: Bool
    ) -> some View {
        let weekdaySymbol = weekdayInitial(for: date)
        let dayNumber = cal.component(.day, from: date)
        let isPeriod = cycle.isPeriodDay(date)
        let isPredicted = cycle.isPredictedOnly(date)
        let isLatePred = cycle.isLatePrediction(date)
        let isFertile = cycle.fertileDays[cycle.dateKey(for: date)] != nil
        let isFutureDay = date > cal.startOfDay(for: Date())

        VStack(spacing: 2) {
            // "TODAY" label or weekday initial
            if isToday {
                Text("TODAY")
                    .font(.custom("Raleway-Bold", size: 9))
                    .foregroundColor(phaseColor(phase))
                    .frame(height: 14)
            } else {
                Text(weekdaySymbol)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(height: 14)
            }

            // Calendar day number with indicator
            ZStack {
                // Confirmed period (past/today): solid circle with fill
                if isPeriod && !isPredicted && !isLatePred && !isFutureDay {
                    Circle()
                        .fill(phaseColor(.menstrual).opacity(0.2))
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(phaseColor(.menstrual).opacity(0.6), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }
                // Confirmed period (future — not yet reached): dashed border, no fill
                else if isPeriod && !isPredicted && !isLatePred && isFutureDay {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                        )
                        .foregroundColor(phaseColor(.menstrual).opacity(0.5))
                        .frame(width: 36, height: 36)
                }
                // Late prediction: muted dashed border, no fill
                else if isLatePred {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                        )
                        .foregroundColor(phaseColor(.menstrual).opacity(0.25))
                        .frame(width: 36, height: 36)
                }
                // Normal prediction: dashed border, no fill
                else if isPredicted {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                        )
                        .foregroundColor(phaseColor(.menstrual).opacity(0.4))
                        .frame(width: 36, height: 36)
                }
                // Selected
                else if isSelected {
                    Circle()
                        .fill(phaseColor(phase).opacity(0.15))
                        .frame(width: 36, height: 36)
                }
                // Today
                else if isToday {
                    Circle()
                        .fill(DesignColors.accent.opacity(0.3))
                        .frame(width: 36, height: 36)
                }

                Text("\(dayNumber)")
                    .font(.custom(isToday || isSelected ? "Raleway-Bold" : "Raleway-Medium", size: 15))
                    .foregroundColor(
                        isPeriod && !isPredicted && !isLatePred ? phaseColor(.menstrual) :
                            isLatePred ? phaseColor(.menstrual).opacity(0.45) :
                            isSelected ? phaseColor(phase) :
                            isToday ? DesignColors.text :
                            DesignColors.textSecondary
                    )
            }
            .frame(width: 40, height: 40)

            // Phase indicator dot
            if isFertile && !isPeriod && !isLatePred {
                Circle()
                    .fill(phaseColor(.ovulatory))
                    .frame(width: 6, height: 6)
            } else if !isPeriod && !isPredicted && !isLatePred {
                if let phase {
                    Circle()
                        .fill(phaseColor(phase).opacity(0.3))
                        .frame(width: 5, height: 5)
                } else {
                    Color.clear.frame(width: 5, height: 5)
                }
            } else {
                Color.clear.frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func weekdayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    private func phaseColor(_ phase: CyclePhase?) -> Color {
        guard let phase else { return DesignColors.textSecondary }
        switch phase {
        case .menstrual: return Color(red: 0.79, green: 0.25, blue: 0.38)
        case .follicular: return Color(red: 0.36, green: 0.72, blue: 0.65)
        case .ovulatory: return Color(red: 0.91, green: 0.66, blue: 0.22)
        case .luteal: return Color(red: 0.55, green: 0.49, blue: 0.78)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        GradientBackground()
            .ignoresSafeArea()

        VStack(spacing: 24) {
            MiniCycleCalendar(
                cycle: CycleContext(
                    cycleDay: 18,
                    cycleLength: 28,
                    bleedingDays: 5,
                    cycleStartDate: Calendar.current.date(byAdding: .day, value: -17, to: Date())!,
                    currentPhase: .luteal,
                    nextPeriodIn: 11,
                    fertileWindowActive: false,
                    periodDays: [],
                    predictedDays: []
                ),
                selectedDate: .constant(nil)
            )
        }
    }
}
