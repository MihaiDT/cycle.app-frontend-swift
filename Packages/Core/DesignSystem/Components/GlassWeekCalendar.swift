import SwiftUI

// MARK: - Glass Week Calendar

/// Bounded cycle-day strip: shows days 1..cycleLength of the current cycle only.
/// Centered on today's cycle day; swipe to explore within the cycle.
/// Tapping a day selects it, updating the ring and center text.
/// Does NOT show past or future cycles — only the active one.
public struct GlassWeekCalendar: View {
    public let cycle: CycleContext
    @Binding public var selectedDate: Date?
    public var isCompact: Bool

    @State private var currentPage: Int = 0
    @State private var highlightSlot: Int = 0
    /// Whether the user has interacted (tap or swipe) — prevents auto-selecting on load
    @State private var userHasInteracted: Bool = false
    /// Track initial page setup
    @State private var didSetInitialPage: Bool = false

    private let cal = Calendar.current
    private let slotsPerPage = 7

    // MARK: - Bounded Cycle Geometry

    /// Total number of days shown — extends past avgCycleLength when the
    /// server prediction falls later, so the predicted period day is reachable.
    private var totalDays: Int { max(cycle.effectiveCycleLength, 1) }

    /// Number of pages needed to display all cycle days (7 per page)
    private var totalPages: Int { max(1, Int(ceil(Double(totalDays) / Double(slotsPerPage)))) }

    /// Valid page range: 0 to totalPages-1
    private var pageRange: ClosedRange<Int> { 0...totalPages - 1 }

    /// Today's cycle day (1-based) clamped within cycle bounds
    private var todayCycleDay: Int {
        min(max(cycle.cycleDay, 1), totalDays)
    }

    /// Page that contains today's cycle day
    private var todayPage: Int {
        (todayCycleDay - 1) / slotsPerPage
    }

    /// Slot within todayPage that corresponds to today
    private var todaySlotInPage: Int {
        (todayCycleDay - 1) % slotsPerPage
    }

    public init(
        cycle: CycleContext,
        selectedDate: Binding<Date?>,
        isCompact: Bool = false
    ) {
        self.cycle = cycle
        self._selectedDate = selectedDate
        self.isCompact = isCompact
    }

    // MARK: - Day Index Helpers

    /// Returns cycle days (1-based) for a given page. Last page may have fewer than 7.
    private func cycleDaysForPage(_ page: Int) -> [Int] {
        let startDay = page * slotsPerPage + 1
        let endDay = min(startDay + slotsPerPage - 1, totalDays)
        guard startDay <= totalDays else { return [] }
        return Array(startDay...endDay)
    }

    /// Convert a cycle day (1-based) to a real Date
    private func dateForCycleDay(_ day: Int) -> Date {
        let cycleStart = cal.startOfDay(for: cycle.cycleStartDate)
        return cal.date(byAdding: .day, value: day - 1, to: cycleStart) ?? cycleStart
    }

    /// Phase label for the highlighted day
    private var phaseLabel: String {
        if cycle.isLate { return "Period Late" }
        let days = cycleDaysForPage(currentPage)
        guard highlightSlot < days.count else {
            return cycle.currentPhase.displayName
        }
        let day = days[highlightSlot]
        let date = dateForCycleDay(day)
        // Future predicted period → "Future Period"
        if cycle.isPredictedOnly(date) {
            return "Future Period"
        }
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: date)
        let phase = cycle.phase(for: date) ?? cycle.phase(forCycleDay: day)
        if d < today {
            return "Past \(phase.displayName)"
        }
        return phase.displayName
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: isCompact ? 2 : 6) {
            if !isCompact {
                // Phase name header
                HStack {
                    Text(phaseLabel)
                        .font(.custom("Raleway-SemiBold", size: 13))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                    Spacer()
                }
            }

            // Day cells + highlight overlay
            ZStack {
                highlightOverlay(slotCount: cycleDaysForPage(currentPage).count)

                TabView(selection: $currentPage) {
                    ForEach(pageRange, id: \.self) { page in
                        dayRow(for: page)
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: isCompact ? 38 : 52)
            }
            .frame(height: isCompact ? 38 : 52)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isCompact)
        .onAppear {
            if !didSetInitialPage {
                currentPage = todayPage
                highlightSlot = todaySlotInPage
                didSetInitialPage = true
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            if newDate == nil {
                userHasInteracted = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    currentPage = todayPage
                    highlightSlot = todaySlotInPage
                }
            }
        }
        .onChange(of: currentPage) { _, _ in
            guard userHasInteracted else { return }
            updateSelectionForCurrentSlot()
        }
    }

    // MARK: - Fixed Highlight Overlay

    private func highlightOverlay(slotCount: Int) -> some View {
        let cellSize: CGFloat = isCompact ? 34 : 44
        return HStack(spacing: 0) {
            ForEach(0..<slotsPerPage, id: \.self) { idx in
                VStack(spacing: 2) {
                    ZStack {
                        if userHasInteracted && idx == highlightSlot && idx < slotCount {
                            Circle()
                                .strokeBorder(
                                    Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.45),
                                    lineWidth: 1.5
                                )
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.12))
                                )
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    .frame(width: cellSize, height: cellSize)

                    if !isCompact {
                        Color.clear.frame(height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Row

    private func dayRow(for page: Int) -> some View {
        let days = cycleDaysForPage(page)
        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { slotIdx, cycleDay in
                dayCellForCycleDay(cycleDay, slotIndex: slotIdx)
                    .frame(maxWidth: .infinity)
            }
            // Pad remaining slots if the last page has fewer than 7 days
            if days.count < slotsPerPage {
                ForEach(days.count..<slotsPerPage, id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompact ? 34 : 44)
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCellForCycleDay(_ day: Int, slotIndex: Int) -> some View {
        let date = dateForCycleDay(day)
        let isToday = day == todayCycleDay
        let calendarDay = cal.component(.day, from: date)
        let periodDay = cycle.isPeriodDay(date)
        // When late, still show predicted days in the week calendar for visual reference
        let rawPredicted = cycle.isLate && cycle.predictedDays.contains(cycle.dateKey(for: date))
        let predictedDay = cycle.isPredictedDay(date) || rawPredicted
        let confirmedPeriod = cycle.isConfirmedPeriod(date)
        let menstrualColor = CyclePhase.menstrual.orbitColor
        let dateKey = cycle.dateKey(for: date)
        let fertilityLevel = cycle.isLate ? nil : cycle.fertileDays[dateKey]
        let isFertile = fertilityLevel != nil
        let isOvulation = cycle.isLate ? false : cycle.ovulationDays.contains(dateKey)
        let oColor = CyclePhase.ovulatory.orbitColor
        let circleSize: CGFloat = isCompact ? 26 : 34

        return VStack(spacing: 2) {
            ZStack {
                // Ovulation day: stronger golden fill + solid ring
                if isOvulation && !periodDay {
                    Circle()
                        .fill(oColor.opacity(0.3))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .strokeBorder(oColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: circleSize, height: circleSize)
                }

                // Other fertile days: subtle fill + dashed ring
                if isFertile && !isOvulation && !periodDay {
                    Circle()
                        .fill(oColor.opacity(0.18))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
                        .foregroundColor(oColor.opacity(0.4))
                        .frame(width: circleSize, height: circleSize)
                }

                // Predicted period day: dashed pink circle (matching full calendar)
                if predictedDay && !confirmedPeriod {
                    Circle()
                        .fill(menstrualColor.opacity(0.18))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                                )
                                .foregroundColor(menstrualColor.opacity(0.4))
                        }
                        .frame(width: circleSize, height: circleSize)
                }

                // Confirmed period day: solid circle (matching full calendar opacity)
                if confirmedPeriod {
                    Circle()
                        .fill(menstrualColor.opacity(0.75))
                        .frame(width: circleSize, height: circleSize)
                }

                // Calendar date number
                Text("\(calendarDay)")
                    .font(
                        .custom(
                            periodDay || isToday ? "Raleway-Bold" : "Raleway-SemiBold",
                            size: isCompact ? 14 : 16
                        )
                    )
                    .foregroundColor(
                        confirmedPeriod
                            ? .white
                            : predictedDay
                                ? DesignColors.text.opacity(0.75)
                                : isToday
                                    ? DesignColors.text
                                    : DesignColors.text.opacity(0.8)
                    )
            }
            .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)

            // Ovulation sparkle indicator below day
            if !isCompact {
                if isOvulation && !periodDay {
                    Image(systemName: "sparkle")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(oColor)
                        .frame(height: 8)
                } else {
                    Color.clear.frame(height: 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let tappedDate = cal.startOfDay(for: date)

            if highlightSlot == slotIndex && isToday && selectedDate == nil {
                return
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                userHasInteracted = true
                highlightSlot = slotIndex
                selectedDate = tappedDate
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Selection Logic

    private func updateSelectionForCurrentSlot() {
        let days = cycleDaysForPage(currentPage)
        guard highlightSlot < days.count else { return }
        let day = days[highlightSlot]
        selectedDate = cal.startOfDay(for: dateForCycleDay(day))
    }
}

// MARK: - Preview

#Preview("Glass Week Calendar") {
    ZStack {
        DesignColors.background
            .ignoresSafeArea()

        GlassWeekCalendar(
            cycle: CycleContext(
                cycleDay: 14,
                cycleLength: 28,
                bleedingDays: 5,
                cycleStartDate: Calendar.current.date(byAdding: .day, value: -13, to: Date())!,
                currentPhase: .ovulatory,
                nextPeriodIn: 15,
                fertileWindowActive: true,
                periodDays: [],
                predictedDays: []
            ),
            selectedDate: .constant(nil)
        )
        .padding(.horizontal, 20)
    }
}
