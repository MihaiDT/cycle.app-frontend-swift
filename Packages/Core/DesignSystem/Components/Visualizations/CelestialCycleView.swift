import SwiftUI

// MARK: - Celestial Cycle View

/// Premium orbital cycle visualization.
///
/// ALL displayed values derive from server data via CycleContext:
/// - Period day number: `CycleContext.periodBlockDay(for:)` (position in server period block)
/// - Phase: `CycleContext.phase(for:)` (menstrual only if date is in server `periodDays`)
/// - Days until period: `CycleContext.daysUntilPeriod(from:)` (searches server calendar)
/// - Cycle day: `CycleContext.cycleDayNumber(for:)` (modular math from `cycleStartDate`)
///
/// `cycle.cycleDay` (raw server value) is never used for display — it can be wrong
/// when `cycleStartDate` is in the future after confirming a period.
public struct CelestialCycleView: View {
    public let cycle: CycleContext
    public var collapseProgress: CGFloat
    @Binding public var exploringDay: Int?
    @Binding public var calendarDate: Date?
    public var onLogPeriod: ((Date?) -> Void)?

    // NOTE: `@State` / `@Environment` properties are implicit-internal (not `private`)
    // so they can be shared with the extension in `CelestialCycleView+Center.swift`.
    @State var isDragging = false
    @State var lastHapticPhase: CyclePhase?
    @State var lastDragAngle: Double?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(
        cycle: CycleContext,
        collapseProgress: CGFloat = 0,
        exploringDay: Binding<Int?>,
        calendarDate: Binding<Date?> = .constant(nil),
        onLogPeriod: ((Date?) -> Void)? = nil
    ) {
        self.cycle = cycle
        self.collapseProgress = collapseProgress
        self._exploringDay = exploringDay
        self._calendarDate = calendarDate
        self.onLogPeriod = onLogPeriod
    }

    // MARK: - Server-Derived Display Properties
    //
    // These are implicit-internal (no `private`) so they can be shared with the
    // extension in `CelestialCycleView+Center.swift`.

    /// Today's cycle day — computed from cycleStartDate, never from server's clamped cycleDay.
    var todayCycleDay: Int {
        cycle.cycleDayNumber(for: Calendar.current.startOfDay(for: Date())) ?? 1
    }

    /// The date the user is looking at — calendar selection or today.
    var effectiveDate: Date {
        calendarDate ?? Calendar.current.startOfDay(for: Date())
    }

    /// Cycle day for the effective date.
    var effectiveCycleDay: Int {
        cycle.cycleDayNumber(for: effectiveDate) ?? todayCycleDay
    }

    /// The day number shown in center text. Priority: drag > calendar > today.
    var displayDay: Int {
        exploringDay ?? effectiveCycleDay
    }

    /// Phase for center text — menstrual ONLY from server periodDays.
    var displayPhase: CyclePhase {
        // When period is late and not dragging, use menstrual for late-window dates
        if cycle.isLate && exploringDay == nil {
            if calendarDate == nil { return .menstrual }
            if let lateness = exploredLateness, lateness >= 0 { return .menstrual }
        }
        if let day = exploringDay {
            return cycle.phase(forCycleDay: day)
        }
        return cycle.phase(for: effectiveDate)
            ?? cycle.phase(forCycleDay: min(effectiveCycleDay, cycle.cycleLength))
    }

    /// Days until next period from the displayed date/day.
    var daysUntilPeriod: Int {
        if let day = exploringDay {
            return cycle.daysUntilPeriod(fromCycleDay: day)
        }
        return cycle.daysUntilPeriod(from: effectiveDate)
    }

    /// Period day number from server block (1-based), nil if not a period day.
    var periodDayFromServer: Int? {
        if let day = exploringDay,
            let date = Calendar.current.date(
                byAdding: .day,
                value: day - 1,
                to: Calendar.current.startOfDay(for: cycle.cycleStartDate)
            )
        {
            return cycle.periodBlockDay(for: date)
        }
        return cycle.periodBlockDay(for: effectiveDate)
    }

    /// Whether the displayed state is "period overdue" (hides day pill).
    var isOverdue: Bool {
        guard cycle.isLate, exploringDay == nil else { return false }
        if let cd = calendarDate {
            guard let lateness = cycle.lateness(for: cd) else { return false }
            return lateness >= 0
        }
        return true
    }

    var isExploring: Bool {
        isDragging || exploringDay != nil || calendarDate != nil
    }

    // MARK: - Ring Position

    /// The cycle day that positions the orb on the ring.
    /// For overdue: pinned at cycleLength (end of ring).
    private var ringDay: Int {
        if let day = exploringDay { return day }
        if cycle.isLate {
            if calendarDate == nil { return cycle.effectiveCycleLength }
            if let lateness = exploredLateness, lateness >= 0 { return cycle.effectiveCycleLength }
        }
        return min(effectiveCycleDay, cycle.effectiveCycleLength)
    }

    /// Pre-computed ring arcs from ACTUAL server data for each day of the cycle.
    /// Groups consecutive days with the same phase into arc segments for efficient Canvas drawing.
    /// This replaces all formula-based phase ranges (CyclePhase.dayRange).
    private var ringArcs: [RingArc] {
        // When period is late (current cycle), show a fully grey ring — phases are unknown
        if cycle.isLate {
            return [RingArc(startDay: 1, endDay: max(cycle.effectiveCycleLength, 1), phase: .luteal, isPredicted: false, isLate: true)]
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var arcs: [RingArc] = []

        for day in 1...max(cycle.effectiveCycleLength, 1) {
            // Convert cycle day → real date → look up server data
            let date = cal.date(byAdding: .day, value: day - cycle.cycleDay, to: today)!
            let key = cycle.dateKey(for: date)

            // Determine phase from server data
            let phase: CyclePhase
            let isPredicted: Bool
            let isFertile = cycle.fertileDays[key] != nil
            let isOvulation = cycle.ovulationDays.contains(key)
            let inPeriod = cycle.periodDays.contains(key)
            let inPredicted = cycle.predictedDays.contains(key)

            if inPeriod && !(cycle.isLate && inPredicted) {
                // Show menstrual arc only for confirmed periods,
                // or predicted periods that are NOT late/overdue.
                phase = .menstrual
                isPredicted = inPredicted
            } else if cycle.isLate && inPredicted {
                // Overdue predicted period — still show as menstrual with dashed styling
                phase = .menstrual
                isPredicted = true
            } else if isOvulation || isFertile {
                phase = .ovulatory
                isPredicted = false
            } else {
                // Fallback: use position-based phase for non-period, non-fertile days
                phase = cycle.phase(forCycleDay: day)
                isPredicted = false
            }

            // Extend last arc if same phase and prediction status
            if let last = arcs.last, last.phase == phase, last.isPredicted == isPredicted {
                arcs[arcs.count - 1] = RingArc(
                    startDay: last.startDay, endDay: day,
                    phase: last.phase, isPredicted: isPredicted
                )
            } else {
                arcs.append(RingArc(
                    startDay: day, endDay: day,
                    phase: phase, isPredicted: isPredicted
                ))
            }
        }

        return arcs
    }

    // MARK: - Collapse

    var hideProgress: Double { min(1, max(0, collapseProgress * 2.5)) }

    // MARK: - Center Text

    var isExploringDay: Bool {
        exploringDay != nil
    }

    /// Whether the effective date is a predicted-only period day (not confirmed by user)
    private var isPredictedPeriod: Bool {
        cycle.isPredictedOnly(effectiveDate)
    }

    /// How late the explored date is relative to expected period.
    var exploredLateness: Int? {
        cycle.lateness(for: effectiveDate)
    }

    /// Days until fertile window starts from the effective date.
    private var daysUntilFertileWindow: Int? {
        guard let fwStart = cycle.fertileWindowStart else { return nil }
        let cal = Calendar.current
        let from = cal.startOfDay(for: effectiveDate)
        let to = cal.startOfDay(for: fwStart)
        guard let days = cal.dateComponents([.day], from: from, to: to).day, days > 0 else { return nil }
        return days
    }

    var centerTitle: String {
        // Late period: show context relative to expected period date
        if cycle.isLate, let lateness = exploredLateness {
            if lateness >= 0 { return "Period" }
            if lateness == -1 { return "Period" }
            // More than 1 day before expected: show normal phase
        }

        if displayPhase == .menstrual && isPredictedPeriod { return "Period" }
        if displayPhase == .menstrual { return "Period" }

        let days = daysUntilPeriod
        if days <= 0 { return isExploringDay ? "Period expected" : "Period" }
        if days <= 7 { return "Period in" }
        if displayPhase == .ovulatory { return "Fertile" }
        if let fwDays = daysUntilFertileWindow, fwDays <= 10 { return "Fertile window" }
        return displayPhase.displayName
    }

    var centerSubtitle: String {
        // Late period: show lateness relative to expected period date
        if cycle.isLate, let lateness = exploredLateness {
            if lateness > 1 { return "\(lateness) days late" }
            if lateness == 1 { return "1 day late" }
            if lateness == 0 { return "expected today" }
            if lateness == -1 { return "starts tomorrow" }
            // More than 1 day before expected: fall through to normal
        }

        if displayPhase == .menstrual && isPredictedPeriod && calendarDate == nil && exploringDay == nil {
            return "may start today"
        }
        if displayPhase == .menstrual {
            return "Day \(periodDayFromServer ?? min(displayDay, cycle.cycleLength))"
        }
        let days = daysUntilPeriod
        if days <= 0 { return isExploringDay ? "today" : "expected today" }
        if days == 1 { return "1 day" }
        if days <= 7 { return "\(days) days" }
        if displayPhase == .ovulatory { return "Window" }
        if let fwDays = daysUntilFertileWindow, fwDays <= 10 {
            return fwDays == 1 ? "in 1 day" : "in \(fwDays) days"
        }
        return "Day \(displayDay)"
    }

    // MARK: - Body

    public var body: some View {
        mainContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityValue("Day \(displayDay) of \(cycle.cycleLength)")
            .accessibilityHint("Swipe up or down to explore cycle days")
            .accessibilityAdjustableAction { direction in
                let current = exploringDay ?? todayCycleDay
                switch direction {
                case .increment:
                    exploringDay = min(cycle.effectiveCycleLength, current + 1)
                    haptic(.light)
                case .decrement:
                    exploringDay = max(1, current - 1)
                    haptic(.light)
                @unknown default: break
                }
            }
            .onChange(of: collapseProgress) { _, newValue in
                if newValue > 0.1 && (exploringDay != nil || calendarDate != nil) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        exploringDay = nil
                        calendarDate = nil
                        isDragging = false
                    }
                }
            }
    }

    private var accessibilityDescription: String {
        var desc = "\(displayPhase.displayName) phase, day \(displayDay) of \(cycle.cycleLength) day cycle"
        if exploringDay != nil { desc += ", exploring" }
        if let n = cycle.nextPeriodIn, n > 0 { desc += ", \(n) days until next period" }
        if cycle.fertileWindowActive { desc += ", fertile window active" }
        return desc
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                displayPhase.glowColor.opacity(isDragging ? 0.12 : 0.07),
                                displayPhase.glowColor.opacity(0.02),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 160
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 20)
                    .opacity(1 - hideProgress)
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: displayPhase)

                // Orbit ring
                CelestialOrbitCanvas(
                    displayDay: ringDay,
                    cycleLength: cycle.effectiveCycleLength,
                    arcs: ringArcs,
                    phase: displayPhase,
                    isDragging: isDragging,
                    reduceMotion: reduceMotion,
                    collapseProgress: collapseProgress
                )
                .frame(width: 340, height: 340)
                .allowsHitTesting(false)
                .overlay {
                    if !reduceMotion {
                        CosmicParticleEmitter(displayDay: ringDay, cycleLength: cycle.effectiveCycleLength)
                            .frame(width: 340, height: 340)
                            .allowsHitTesting(false)
                            .opacity(1 - hideProgress)
                    }
                }

                // Center text + button
                VStack(spacing: 12) {
                    centerContentView
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: displayDay)

                    if let onLogPeriod, collapseProgress < 0.1 {
                        logPeriodButton(onLogPeriod)
                    }
                }

                // Drag gesture
                gestureOverlay.allowsHitTesting(collapseProgress < 0.1)
            }

            // Context pills
            contextPills
                .opacity(1 - hideProgress)
                .padding(.top, 16)
                .animation(reduceMotion ? nil : .appBalanced, value: displayDay)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: displayPhase)
    }
}
