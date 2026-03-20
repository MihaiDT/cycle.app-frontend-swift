import SwiftUI

// MARK: - Glass Week Calendar

/// Infinite cycle-day loop strip: shows days 1..cycleLength repeating forever.
/// Centered on today's cycle day; swipe to scroll through the loop.
/// Tapping a day selects it, updating the ring and center text.
public struct GlassWeekCalendar: View {
    public let cycle: CycleContext
    @Binding public var selectedDate: Date?
    public var isCompact: Bool

    @State private var pageOffset: Int = 0
    @State private var highlightSlot: Int = 3
    /// Whether the user has interacted (tap or swipe) — prevents auto-selecting on load
    @State private var userHasInteracted: Bool = false

    private let cal = Calendar.current
    private let slotsPerPage = 7
    private let centerSlot = 3

    /// Today's 0-based index in the infinite sequence (anchored at 0)
    private var todayIndex: Int { 0 }

    /// Page range matching full calendar: ±12 months (~365 days ÷ 7 = ~52 pages each way)
    private var pageRange: ClosedRange<Int> { -52...52 }

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

    /// Returns 7 indices for a given page (relative to todayIndex)
    private func dayIndices(for page: Int) -> [Int] {
        let centerIndex = todayIndex + page * slotsPerPage
        return (-centerSlot...(slotsPerPage - 1 - centerSlot)).map { centerIndex + $0 }
    }

    /// Cycle day number (1‑based) — delegates to CycleContext for predicted block awareness.
    private func cycleDay(for index: Int) -> Int {
        let date = dateForIndex(index)
        return cycle.cycleDayNumber(for: date)
            ?? {
                // Fallback: modular math for dates outside CycleContext's range
                guard cycle.cycleLength > 0 else { return 1 }
                let raw = (cycle.cycleDay - 1) + index
                let mod = raw % cycle.cycleLength
                return (mod < 0 ? mod + cycle.cycleLength : mod) + 1
            }()
    }

    /// Convert an index to a real Date (for period/predicted lookups)
    private func dateForIndex(_ index: Int) -> Date {
        cal.date(byAdding: .day, value: index, to: cal.startOfDay(for: Date())) ?? Date()
    }

    /// Phase label for the selected day
    private var phaseLabel: String {
        let indices = dayIndices(for: pageOffset)
        let highlightIndex = indices[highlightSlot]
        let date = dateForIndex(highlightIndex)
        let phase = cycle.phase(for: date) ?? cycle.phase(forCycleDay: cycleDay(for: highlightIndex))
        return phase.displayName
    }

    /// Short date label: "20 Mar"
    private func shortDateLabel(_ date: Date) -> String {
        let day = cal.component(.day, from: date)
        let month = cal.shortMonthSymbols[cal.component(.month, from: date) - 1]
        return "\(day) \(month)"
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
                highlightOverlay

                TabView(selection: $pageOffset) {
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
        .onChange(of: selectedDate) { _, newDate in
            if newDate == nil {
                userHasInteracted = false
                highlightSlot = centerSlot
                if pageOffset != 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        pageOffset = 0
                    }
                }
            }
        }
        .onChange(of: pageOffset) { _, newPage in
            if newPage != 0 { userHasInteracted = true }
            guard userHasInteracted else { return }
            updateSelectionForCurrentSlot()
        }
    }

    // MARK: - Fixed Highlight Overlay

    private var highlightOverlay: some View {
        let cellSize: CGFloat = isCompact ? 34 : 44
        return HStack(spacing: 0) {
            ForEach(0..<slotsPerPage, id: \.self) { idx in
                VStack(spacing: 2) {
                    ZStack {
                        if idx == highlightSlot {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.5))
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
        let indices = dayIndices(for: page)
        return HStack(spacing: 0) {
            ForEach(Array(indices.enumerated()), id: \.offset) { slotIdx, dayIdx in
                dayCell(dayIndex: dayIdx, slotIndex: slotIdx)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(dayIndex: Int, slotIndex: Int) -> some View {
        let isTodayDay = dayIndex == todayIndex
        let date = dateForIndex(dayIndex)
        let calendarDay = cal.component(.day, from: date)
        let periodDay = cycle.isPeriodDay(date)
        let predictedDay = cycle.isPredictedDay(date)
        let confirmedPeriod = cycle.isConfirmedPeriod(date)
        let isPast = dayIndex < todayIndex
        let menstrualColor = CyclePhase.menstrual.orbitColor
        let dateKey = cycle.dateKey(for: date)
        let fertilityLevel = cycle.fertileDays[dateKey]
        let isFertile = fertilityLevel != nil
        let isOvulation = cycle.ovulationDays.contains(dateKey)
        let oColor = CyclePhase.ovulatory.orbitColor
        let circleSize: CGFloat = isCompact ? 26 : 34

        return VStack(spacing: 2) {
            ZStack {
                // Ovulation day: golden tint fill
                if isOvulation && !periodDay {
                    Circle()
                        .fill(oColor.opacity(0.18))
                        .frame(width: circleSize, height: circleSize)
                }

                // Fertile day (non-ovulation, non-period): subtle tint fill
                if isFertile && !isOvulation && !periodDay {
                    Circle()
                        .fill((fertilityLevel?.color ?? oColor).opacity(0.12))
                        .frame(width: circleSize, height: circleSize)
                }

                // Fertile/ovulation ring
                if (isFertile || isOvulation) && !periodDay {
                    Circle()
                        .strokeBorder(
                            fertilityLevel?.color ?? oColor.opacity(0.4),
                            lineWidth: isOvulation ? 2 : 1.5
                        )
                        .frame(width: circleSize, height: circleSize)
                }

                // Predicted period day: dashed pink circle
                if predictedDay {
                    Circle()
                        .fill(menstrualColor.opacity(0.2))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                                .foregroundColor(menstrualColor.opacity(0.6))
                        }
                        .frame(width: circleSize, height: circleSize)
                }

                // Confirmed period day: solid pink circle
                if confirmedPeriod {
                    Circle()
                        .fill(menstrualColor.opacity(isPast ? 0.75 : 0.45))
                        .frame(width: circleSize, height: circleSize)
                }

                // Ovulation sparkle icon
                if isOvulation && !periodDay && !isCompact {
                    Image(systemName: "sparkle")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(oColor)
                        .offset(x: 13, y: -13)
                }

                // Calendar date number
                Text("\(calendarDay)")
                    .font(
                        .custom(
                            periodDay || isTodayDay ? "Raleway-Bold" : "Raleway-SemiBold",
                            size: isCompact ? 14 : 16
                        )
                    )
                    .foregroundColor(
                        confirmedPeriod
                            ? .white
                            : predictedDay
                                ? menstrualColor
                                : isTodayDay
                                    ? DesignColors.text
                                    : DesignColors.text.opacity(0.8)
                    )
            }
            .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)
            .shadow(
                color: isOvulation && !periodDay
                    ? oColor.opacity(0.2)
                    : .clear,
                radius: 6,
                x: 0,
                y: 2
            )

            // Dot indicator
            if !isCompact {
                if periodDay {
                    Circle()
                        .fill(menstrualColor.opacity(isPast ? 0.7 : 0.4))
                        .frame(width: 5, height: 5)
                        .frame(height: 8)
                } else if isFertile || isOvulation {
                    Circle()
                        .fill(fertilityLevel?.color ?? oColor.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .frame(height: 8)
                } else {
                    Color.clear.frame(height: 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let tappedDate = cal.startOfDay(for: date)

            if highlightSlot == slotIndex && isTodayDay && selectedDate == nil {
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
        let indices = dayIndices(for: pageOffset)
        guard highlightSlot < indices.count else { return }
        let dayIdx = indices[highlightSlot]
        selectedDate = cal.startOfDay(for: dateForIndex(dayIdx))
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
