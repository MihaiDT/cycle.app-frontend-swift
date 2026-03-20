import Foundation

// MARK: - Cycle Context

/// Single source of truth for all cycle-related data and computations.
/// Built from server responses (menstrual status + calendar API).
/// Both GlassWeekCalendar and CelestialCycleView read from this — no local math anywhere else.
public struct CycleContext: Equatable, Sendable {
    public let cycleDay: Int
    public let cycleLength: Int
    public let bleedingDays: Int
    public let cycleStartDate: Date
    public let currentPhase: CyclePhase
    public let nextPeriodIn: Int?
    public let fertileWindowActive: Bool
    /// All period days from server calendar: confirmed + predicted (keys: "yyyy-MM-dd")
    public let periodDays: Set<String>
    /// Predicted-only subset (for dashed styling)
    public let predictedDays: Set<String>
    /// Fertile days with level from server calendar (keys: "yyyy-MM-dd")
    public let fertileDays: [String: FertilityLevel]
    /// Ovulation day keys from server calendar (keys: "yyyy-MM-dd")
    public let ovulationDays: Set<String>
    /// Fertile window dates from status API
    public let fertileWindowStart: Date?
    public let fertileWindowEnd: Date?
    public let fertileWindowPeak: Date?
    public let daysUntilOvulation: Int?

    private let cal = Calendar.current

    public init(
        cycleDay: Int,
        cycleLength: Int,
        bleedingDays: Int,
        cycleStartDate: Date,
        currentPhase: CyclePhase,
        nextPeriodIn: Int?,
        fertileWindowActive: Bool,
        periodDays: Set<String>,
        predictedDays: Set<String>,
        fertileDays: [String: FertilityLevel] = [:],
        ovulationDays: Set<String> = [],
        fertileWindowStart: Date? = nil,
        fertileWindowEnd: Date? = nil,
        fertileWindowPeak: Date? = nil,
        daysUntilOvulation: Int? = nil
    ) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.bleedingDays = bleedingDays
        self.cycleStartDate = cycleStartDate
        self.currentPhase = currentPhase
        self.nextPeriodIn = nextPeriodIn
        self.fertileWindowActive = fertileWindowActive
        self.periodDays = periodDays
        self.predictedDays = predictedDays
        self.fertileDays = fertileDays
        self.ovulationDays = ovulationDays
        self.fertileWindowStart = fertileWindowStart
        self.fertileWindowEnd = fertileWindowEnd
        self.fertileWindowPeak = fertileWindowPeak
        self.daysUntilOvulation = daysUntilOvulation
    }

    /// Actual bleeding days derived from server period data (confirmed + predicted).
    /// Falls back to profile `bleedingDays` when no period data is available.
    public var effectiveBleedingDays: Int {
        guard !periodDays.isEmpty else { return bleedingDays }
        let start = cal.startOfDay(for: cycleStartDate)
        var count = 0
        for i in 0..<cycleLength {
            guard let date = cal.date(byAdding: .day, value: i, to: start) else { break }
            if periodDays.contains(dateKey(for: date)) {
                count += 1
            } else if count > 0 {
                break // end of consecutive period block
            }
        }
        return max(count, bleedingDays)
    }

    // MARK: - Date Key (thread-safe, no DateFormatter)

    public func dateKey(for date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Period Detection (server only)

    public func isPeriodDay(_ date: Date) -> Bool {
        periodDays.contains(dateKey(for: date))
    }

    public func isPredictedDay(_ date: Date) -> Bool {
        predictedDays.contains(dateKey(for: date))
    }

    public func isConfirmedPeriod(_ date: Date) -> Bool {
        isPeriodDay(date) && !isPredictedDay(date)
    }

    // MARK: - Cycle Day Calculation

    /// Cycle day number (1-based) and offset (0=current cycle, 1=next, etc.)
    public func cycleDayInfo(for date: Date) -> (day: Int, offset: Int)? {
        let d = cal.startOfDay(for: date)
        let key = dateKey(for: d)

        // Check if the date is within the current cycle's span
        let daysDiffFromStart = cal.dateComponents([.day], from: cal.startOfDay(for: cycleStartDate), to: d).day ?? 0
        let isCurrentCycle = daysDiffFromStart >= 0 && daysDiffFromStart < cycleLength

        // Predicted period days in future cycles: find block start, compute day relative to it
        // Skip this branch for current-cycle days (e.g. future bleeding days) — use normal math
        if predictedDays.contains(key) && !isCurrentCycle {
            let blockStart = predictedBlockStart(for: d)
            let dayInPeriod = (cal.dateComponents([.day], from: blockStart, to: d).day ?? 0) + 1
            let baseDiff = cal.dateComponents([.day], from: cal.startOfDay(for: cycleStartDate), to: blockStart).day ?? 0
            let offset = baseDiff > 0 ? baseDiff / cycleLength + 1 : 1
            return (dayInPeriod, offset)
        }

        // Past dates (before cycle start): wrap modularly into previous cycles
        if daysDiffFromStart < 0 {
            guard cycleLength > 0 else { return nil }
            let mod = ((daysDiffFromStart % cycleLength) + cycleLength) % cycleLength
            return (mod + 1, daysDiffFromStart / cycleLength - (daysDiffFromStart % cycleLength == 0 ? 0 : 1))
        }
        return (daysDiffFromStart % cycleLength + 1, daysDiffFromStart / cycleLength)
    }

    /// Just the cycle day number for a date
    public func cycleDayNumber(for date: Date) -> Int? {
        cycleDayInfo(for: date)?.day
    }

    // MARK: - Phase Resolution (server period data → math fallback)

    /// Phase for a specific date — server is source of truth for menstrual
    public func phase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        guard let info = cycleDayInfo(for: date) else { return nil }
        let p = mathPhase(forCycleDay: info.day)
        // For future cycles (offset > 0), menstrual only from server data — never from math
        if p == .menstrual && info.offset > 0 { return .follicular }
        return p
    }

    /// Phase for a cycle day number — checks server data for the corresponding date
    public func phase(forCycleDay day: Int) -> CyclePhase {
        if let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycleStartDate)) {
            if periodDays.contains(dateKey(for: date)) {
                return .menstrual
            }
        }
        let p = mathPhase(forCycleDay: day)
        // Current cycle only: menstrual from math is fine (offset 0)
        return p
    }

    /// Phase for the dot indicator — menstrual only from server, suppresses local-math menstrual
    public func dotPhase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        guard let cd = cycleDayNumber(for: date) else { return nil }
        let p = mathPhase(forCycleDay: cd)
        return p == .menstrual ? .follicular : p
    }

    // MARK: - Days Until Next Period

    /// Days until next period from a given display day (searches server calendar entries)
    public func daysUntilPeriod(fromCycleDay displayDay: Int) -> Int {
        if !periodDays.isEmpty {
            let today = cal.startOfDay(for: Date())
            let dayOffset = displayDay - cycleDay
            let displayDate = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today

            for i in 1...cycleLength {
                if let futureDate = cal.date(byAdding: .day, value: i, to: displayDate) {
                    if periodDays.contains(dateKey(for: futureDate)) {
                        return i
                    }
                }
            }
        }
        if let nextPeriodIn {
            let dayOffset = displayDay - cycleDay
            return max(0, nextPeriodIn - dayOffset)
        }
        return cycleLength - displayDay + 1
    }

    /// Days until next period from a specific date (accurate for any cycle offset)
    public func daysUntilPeriod(from date: Date) -> Int {
        let d = cal.startOfDay(for: date)
        if !periodDays.isEmpty {
            for i in 1...cycleLength {
                if let futureDate = cal.date(byAdding: .day, value: i, to: d) {
                    if periodDays.contains(dateKey(for: futureDate)) {
                        return i
                    }
                }
            }
        }
        // Fallback: use cycle day math
        if let info = cycleDayInfo(for: d) {
            return cycleLength - info.day + 1
        }
        return cycleLength
    }

    // MARK: - Private

    private func mathPhase(forCycleDay day: Int) -> CyclePhase {
        for p in CyclePhase.allCases {
            if p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays).contains(day) {
                return p
            }
        }
        return .luteal
    }

    /// Finds start of a contiguous predicted period block containing `date`.
    private func predictedBlockStart(for date: Date) -> Date {
        var start = date
        for i in 1...10 {
            guard let prev = cal.date(byAdding: .day, value: -i, to: date) else { break }
            if predictedDays.contains(dateKey(for: prev)) {
                start = prev
            } else {
                break
            }
        }
        return start
    }

    /// Day number (1-based) within the contiguous period block containing `date`.
    /// Works for both confirmed and predicted period blocks.
    public func periodBlockDay(for date: Date) -> Int? {
        let d = cal.startOfDay(for: date)
        let key = dateKey(for: d)
        guard periodDays.contains(key) else { return nil }
        var start = d
        for i in 1...10 {
            guard let prev = cal.date(byAdding: .day, value: -i, to: d) else { break }
            if periodDays.contains(dateKey(for: prev)) {
                start = prev
            } else {
                break
            }
        }
        return (cal.dateComponents([.day], from: start, to: d).day ?? 0) + 1
    }
}

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

        // Convert server UTC date to local calendar date
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: status.currentCycle.startDate)
        var localStart = cal.date(from: comps) ?? status.currentCycle.startDate
        var cycleDay = status.currentCycle.cycleDay

        // Reconcile cycleDay with prediction when they're inconsistent.
        // The server wraps cycleDay via modular arithmetic which can give Day 1
        // while the prediction says period is only a few days away.
        if let daysUntil = status.nextPrediction?.daysUntil,
           daysUntil > 0, daysUntil < cycleLength
        {
            let expectedCycleDay = cycleLength - daysUntil + 1
            // Only override when the server's wrapping gave a clearly wrong value
            // (e.g. Day 1 when we should be Day 26)
            if abs(expectedCycleDay - cycleDay) > 3 {
                cycleDay = expectedCycleDay
                // Derive start date from prediction-aligned cycle day
                let today = cal.startOfDay(for: Date())
                localStart = cal.date(byAdding: .day, value: -(cycleDay - 1), to: today) ?? localStart
            }
        }

        let phase = CyclePhase(rawValue: status.currentCycle.phase)
            ?? CycleContext.mathPhaseStatic(forCycleDay: cycleDay, cycleLength: cycleLength, bleedingDays: bleedingDays)

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
            daysUntilOvulation: status.fertileWindow?.daysUntilPeak
        )
    }

    /// Static phase calculation for use in factory (before instance exists)
    private static func mathPhaseStatic(forCycleDay day: Int, cycleLength: Int, bleedingDays: Int) -> CyclePhase {
        for p in CyclePhase.allCases {
            if p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays).contains(day) {
                return p
            }
        }
        return .luteal
    }
}
