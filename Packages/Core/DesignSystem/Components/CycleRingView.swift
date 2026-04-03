import SwiftUI

// MARK: - Cycle Ring View (Clue-style)

/// A circular ring showing the current menstrual cycle with phase-colored arcs,
/// a "today" indicator, and center text showing days until next period.
/// Adapted from Clue's design to use the app's warm premium palette.
public struct CycleRingView: View {
    public let cycle: CycleContext
    /// Currently selected cycle day (1-based) from mini calendar interaction
    public var selectedDay: Int?

    private let ringSize: CGFloat = 280
    private let ringWidth: CGFloat = 18
    private let todayDotSize: CGFloat = 32
    private let cal = Calendar.current

    public init(cycle: CycleContext, selectedDay: Int? = nil) {
        self.cycle = cycle
        self.selectedDay = selectedDay
    }

    // MARK: - Computed

    /// The cycle day to highlight (selected or today)
    private var displayDay: Int {
        selectedDay ?? cycle.cycleDay
    }

    /// Total days shown on the ring — extends past cycleLength when period is late
    private var ringDays: Int {
        if cycle.isLate {
            return max(cycle.cycleLength, cycle.cycleDay)
        }
        return cycle.cycleLength
    }

    /// Angle per cycle day — scales to fit ringDays (expands when late)
    private var anglePerDay: Double {
        360.0 / Double(ringDays)
    }

    /// Start angle offset — cycle starts at top (12 o'clock = -90°)
    private let startAngle: Double = -90

    /// Angle for a given cycle day (1-based)
    private func angle(forDay day: Int) -> Double {
        startAngle + Double(day - 1) * anglePerDay
    }

    /// Center angle for the today/selected indicator
    private var todayAngle: Double {
        angle(forDay: displayDay) + anglePerDay / 2
    }

    private var daysUntilPeriod: Int {
        cycle.daysUntilPeriod(fromCycleDay: displayDay)
    }

    /// Which day of the current period block (e.g. "Period day 3")
    private var currentPeriodBlockDay: Int {
        if selectedDay != nil {
            return cycle.periodBlockDay(for: displayDate) ?? displayDay
        }
        return cycle.periodBlockDay(for: Date()) ?? displayDay
    }

    private var displayPhase: CyclePhase {
        if let selectedDay {
            return cycle.phase(forCycleDay: selectedDay)
        }
        return cycle.currentPhase
    }

    private var displayDate: Date {
        if let selectedDay {
            return cal.date(
                byAdding: .day,
                value: selectedDay - cycle.cycleDay,
                to: cal.startOfDay(for: Date())
            ) ?? Date()
        }
        return Date()
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background ring track
            Circle()
                .stroke(
                    DesignColors.divider.opacity(0.3),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)

            // Phase arcs (solid, days 1..cycleLength)
            phaseArcs

            // Predicted period overlay (dashed menstrual at end of cycle)
            predictedPeriodArc

            // Late extension (dashed pulsing arc beyond cycleLength)
            lateExtensionArc

            // Period dots (small dots for each period day on the ring)
            periodDayDots

            // Fertile day markers
            fertileDayMarkers

            // Today / Selected day indicator
            todayIndicator

            // Center text
            centerContent
        }
        .frame(width: ringSize + todayDotSize, height: ringSize + todayDotSize)
    }

    // MARK: - Phase Arcs

    @ViewBuilder
    private var phaseArcs: some View {
        let length = cycle.cycleLength
        let total = ringDays
        let phases: [(phase: CyclePhase, range: ClosedRange<Int>)] = computePhaseRanges(length: length)

        ForEach(Array(phases.enumerated()), id: \.offset) { _, item in
            PhaseArc(
                startDay: item.range.lowerBound,
                endDay: item.range.upperBound,
                cycleLength: total,
                phase: item.phase,
                ringSize: ringSize,
                ringWidth: ringWidth
            )
        }
    }

    /// Phase for a cycle day derived directly from server calendar data.
    /// Period/fertile/ovulation come from backend; follicular vs luteal
    /// is determined by position relative to the server fertile window.
    /// Predicted period days at the end of the cycle (next cycle prediction)
    /// are NOT colored as menstrual — only current cycle's period is red.
    private func serverPhase(forDay day: Int) -> CyclePhase {
        guard let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycle.cycleStartDate))
        else { return .follicular }
        let key = cycle.dateKey(for: date)

        // All period days (confirmed + predicted) show as menstrual on the ring.
        // Predicted days get a dashed overlay via predictedPeriodArc for visual distinction.
        if cycle.isPeriodDay(date) { return .menstrual }
        if cycle.ovulationDays.contains(key) { return .ovulatory }
        if cycle.fertileDays[key] != nil { return .ovulatory }

        // No server entry → position relative to fertile window
        let fw = cycle.fertileWindowDayRange(for: date)
        if day < fw.lowerBound { return .follicular }
        if fw.contains(day) { return .ovulatory }
        return .luteal
    }

    /// Build contiguous phase ranges from server data.
    private func computePhaseRanges(length: Int) -> [(phase: CyclePhase, range: ClosedRange<Int>)] {
        guard length > 0 else { return [] }
        var result: [(phase: CyclePhase, range: ClosedRange<Int>)] = []
        var currentPhase = serverPhase(forDay: 1)
        var rangeStart = 1

        for day in 2...length {
            let phase = serverPhase(forDay: day)
            if phase != currentPhase {
                result.append((currentPhase, rangeStart...day - 1))
                currentPhase = phase
                rangeStart = day
            }
        }
        result.append((currentPhase, rangeStart...length))
        return result
    }

    // MARK: - Predicted Period Arc

    /// Range of predicted period days on the ring (for dashed overlay distinction).
    private var predictedPeriodRange: (start: Int, end: Int)? {
        let startOfCycle = cal.startOfDay(for: cycle.cycleStartDate)
        var pStart: Int?
        var pEnd: Int?
        for day in 1...cycle.cycleLength {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: startOfCycle) else { continue }
            if cycle.isPredictedOnly(date) {
                if pStart == nil { pStart = day }
                pEnd = day
            }
        }
        guard let s = pStart, let e = pEnd else { return nil }
        return (s, e)
    }

    /// Dashed menstrual arc overlaying predicted period days at end of cycle.
    @ViewBuilder
    private var predictedPeriodArc: some View {
        if let range = predictedPeriodRange {
            let total = ringDays
            Circle()
                .trim(
                    from: CGFloat(range.start - 1) / CGFloat(total),
                    to: CGFloat(range.end) / CGFloat(total)
                )
                .stroke(
                    phaseColor(.menstrual).opacity(0.35),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt, dash: [5, 4])
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: - Late Extension Arc

    /// Dashed arc beyond cycleLength when the period is late.
    /// Visually extends the ring with a pulsing menstrual-colored zone.
    @ViewBuilder
    private var lateExtensionArc: some View {
        if cycle.isLate && cycle.cycleDay > cycle.cycleLength {
            let total = ringDays
            Circle()
                .trim(
                    from: CGFloat(cycle.cycleLength) / CGFloat(total),
                    to: CGFloat(cycle.cycleDay) / CGFloat(total)
                )
                .stroke(
                    phaseColor(.menstrual).opacity(0.3),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt, dash: [6, 4])
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: - Period Day Dots

    @ViewBuilder
    private var periodDayDots: some View {
        let length = ringDays
        ForEach(1...length, id: \.self) { day in
            let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycle.cycleStartDate))!
            if cycle.isPeriodDay(date) {
                let isPredicted = cycle.isPredictedOnly(date)
                let a = angle(forDay: day) + anglePerDay / 2
                let radius = ringSize / 2

                Circle()
                    .fill(phaseColor(.menstrual).opacity(isPredicted ? 0.4 : 0.9))
                    .frame(width: 5, height: 5)
                    .offset(
                        x: radius * cos(a.radians),
                        y: radius * sin(a.radians)
                    )
            }
        }
    }

    // MARK: - Fertile Day Markers

    @ViewBuilder
    private var fertileDayMarkers: some View {
        let length = ringDays
        ForEach(1...length, id: \.self) { day in
            let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycle.cycleStartDate))!
            let key = cycle.dateKey(for: date)
            if let level = cycle.fertileDays[key] {
                let a = angle(forDay: day) + anglePerDay / 2
                let radius = ringSize / 2

                Circle()
                    .fill(level.color.opacity(0.8))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: radius * cos(a.radians),
                        y: radius * sin(a.radians)
                    )
            }
        }
    }

    // MARK: - Today Indicator

    @ViewBuilder
    private var todayIndicator: some View {
        let a = todayAngle
        let radius = ringSize / 2

        ZStack {
            // Outer glow
            Circle()
                .fill(phaseColor(displayPhase).opacity(0.15))
                .frame(width: todayDotSize + 8, height: todayDotSize + 8)

            // Background circle
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: todayDotSize, height: todayDotSize)

            // Day number
            VStack(spacing: 0) {
                Text("Day")
                    .font(.custom("Raleway-Medium", size: 8))
                    .foregroundColor(DesignColors.textSecondary)
                Text("\(displayDay)")
                    .font(.custom("Raleway-Bold", size: 14))
                    .foregroundColor(phaseColor(displayPhase))
            }
        }
        .shadow(color: phaseColor(displayPhase).opacity(0.3), radius: 6, x: 0, y: 2)
        .offset(
            x: radius * cos(a.radians),
            y: radius * sin(a.radians)
        )
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 6) {
            // Date
            Text(selectedDay == nil ? "Today" : dateLabel(for: displayDate))
                .font(.custom("Raleway-Medium", size: 13))
                .foregroundColor(DesignColors.textSecondary)
            +
            Text(selectedDay == nil ? ", \(dateLabel(for: Date()))" : "")
                .font(.custom("Raleway-Medium", size: 13))
                .foregroundColor(DesignColors.textSecondary)

            // Days until period / status
            if cycle.isLate && selectedDay == nil {
                Text("Period is\n\(cycle.daysLate) days late")
                    .font(.custom("Raleway-Bold", size: 22))
                    .foregroundColor(phaseColor(.menstrual))
                    .multilineTextAlignment(.center)
            } else if displayPhase == .menstrual {
                Text("Period day \(currentPeriodBlockDay)")
                    .font(.custom("Raleway-Bold", size: 22))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
            } else if daysUntilPeriod == 0 {
                Text("Period expected\ntoday")
                    .font(.custom("Raleway-Bold", size: 22))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(daysUntilPeriod) days until your\nnext period")
                    .font(.custom("Raleway-Bold", size: 22))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
            }

            // Phase / fertile indicator
            if cycle.fertileWindowActive && selectedDay == nil {
                HStack(spacing: 4) {
                    Text("Potential fertile day")
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(phaseColor(.ovulatory))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(phaseColor(.ovulatory))
                }
            } else {
                Text(displayPhase.displayName)
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(phaseColor(displayPhase).opacity(0.8))
            }
        }
        .frame(width: ringSize - ringWidth * 2 - 20)
    }

    // MARK: - Helpers

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func phaseColor(_ phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual: return Color(red: 0.79, green: 0.25, blue: 0.38)
        case .follicular: return Color(red: 0.36, green: 0.72, blue: 0.65)
        case .ovulatory: return Color(red: 0.91, green: 0.66, blue: 0.22)
        case .luteal: return Color(red: 0.55, green: 0.49, blue: 0.78)
        }
    }
}

// MARK: - Phase Arc

private struct PhaseArc: View {
    let startDay: Int
    let endDay: Int
    let cycleLength: Int
    let phase: CyclePhase
    let ringSize: CGFloat
    let ringWidth: CGFloat

    private let baseAngle: Double = -90

    private var startAngle: Angle {
        .degrees(baseAngle + Double(startDay - 1) / Double(cycleLength) * 360)
    }

    private var endAngle: Angle {
        .degrees(baseAngle + Double(endDay) / Double(cycleLength) * 360)
    }

    var body: some View {
        Circle()
            .trim(
                from: CGFloat(startDay - 1) / CGFloat(cycleLength),
                to: CGFloat(endDay) / CGFloat(cycleLength)
            )
            .stroke(
                phaseGradient,
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
            )
            .frame(width: ringSize, height: ringSize)
            .rotationEffect(.degrees(-90))
    }

    private var phaseGradient: some ShapeStyle {
        let color = phaseColor(phase)
        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func phaseColor(_ phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual: return Color(red: 0.79, green: 0.25, blue: 0.38)
        case .follicular: return Color(red: 0.36, green: 0.72, blue: 0.65)
        case .ovulatory: return Color(red: 0.91, green: 0.66, blue: 0.22)
        case .luteal: return Color(red: 0.55, green: 0.49, blue: 0.78)
        }
    }
}

// MARK: - Angle Extension

private extension Double {
    var radians: Double { self * .pi / 180 }
}

// MARK: - Preview

#Preview {
    ZStack {
        GradientBackground()
            .ignoresSafeArea()

        CycleRingView(
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
            )
        )
    }
}
