import Foundation

// MARK: - CycleContext › Factory
//
// Builds CycleContext from server payloads — lifted out of the main
// struct so CycleContext.swift stays focused on accessors and phase
// resolution.

// MARK: - Factory

extension CycleContext {
    /// Build from server responses. Returns nil if no cycle data.
    public static func from(
        status: MenstrualStatusResponse,
        periodDays: Set<String>,
        predictedDays: Set<String>,
        fertileDays: [String: FertilityLevel] = [:],
        ovulationDays: Set<String> = []
    ) -> CycleContext? {
        guard status.hasCycleData else { return nil }

        let cal = Calendar.current
        let cycleLength = status.profile.avgCycleLength
        let bleedingDays = status.currentCycle.bleedingDays

        // Convert server date to local calendar date.
        // Server dates may carry a non-UTC timezone (e.g. EEST +03:00), so adding 12h
        // before extracting UTC components ensures the correct calendar day.
        let noon = status.currentCycle.startDate.addingTimeInterval(12 * 3600)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: noon)
        var localStart = cal.date(from: comps) ?? status.currentCycle.startDate
        var cycleDay = status.currentCycle.cycleDay
        let today = cal.startOfDay(for: Date())

        // Reconcile cycleDay with prediction when they're inconsistent.
        // The server wraps cycleDay via modular arithmetic which can give Day 1
        // while the prediction says period is only a few days away.
        // Skip when period is genuinely late — don't override real Day 42 with wrapped Day 14.
        if cycleDay <= cycleLength,
            let daysUntil = status.nextPrediction?.daysUntil,
            daysUntil > 0, daysUntil < cycleLength
        {
            let expectedCycleDay = cycleLength - daysUntil + 1
            // Only override when the server's wrapping gave a clearly wrong value
            // (e.g. Day 1 when we should be Day 26)
            if abs(expectedCycleDay - cycleDay) > 3 {
                cycleDay = expectedCycleDay
                localStart = cal.date(byAdding: .day, value: -(cycleDay - 1), to: today) ?? localStart
            }
        }

        // Late detection: from prediction OR from cycle day exceeding average length
        let isLateFromPrediction = status.nextPrediction?.isLate ?? false
        let isLateFromCycleDay = cycleDay > cycleLength
        let isLate = isLateFromPrediction || isLateFromCycleDay
        let daysLate = max(
            status.nextPrediction?.daysLate ?? 0,
            isLateFromCycleDay ? cycleDay - cycleLength : 0
        )

        let phase: CyclePhase = if isLate {
            .late
        } else {
            CyclePhase(rawValue: status.currentCycle.phase)
                ?? CycleContext.mathPhaseStatic(forCycleDay: cycleDay, cycleLength: cycleLength, bleedingDays: bleedingDays)
        }

        return CycleContext(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays,
            cycleStartDate: localStart,
            currentPhase: phase,
            nextPeriodIn: status.nextPrediction?.daysUntil,
            fertileWindowActive: status.fertileWindow?.isActive ?? false,
            periodDays: periodDays,
            predictedDays: predictedDays,
            fertileDays: fertileDays,
            ovulationDays: ovulationDays,
            fertileWindowStart: status.fertileWindow?.start,
            fertileWindowEnd: status.fertileWindow?.end,
            fertileWindowPeak: status.fertileWindow?.peak,
            daysUntilOvulation: status.fertileWindow?.daysUntilPeak,
            isLate: isLate,
            daysLate: daysLate
        )
    }

    /// Static phase calculation for use in factory (before instance exists)
    private static func mathPhaseStatic(forCycleDay day: Int, cycleLength: Int, bleedingDays: Int) -> CyclePhase {
        let result = CycleMath.cyclePhase(cycleDay: day, cycleLength: cycleLength, bleedingDays: bleedingDays)
        return CyclePhase(rawValue: result.rawValue) ?? .luteal
    }

}
