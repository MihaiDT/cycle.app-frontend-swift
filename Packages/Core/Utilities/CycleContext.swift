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

    /// Effective length for ring/calendar display: extends past `cycleLength` when the
    /// server prediction falls later than the profile average. This ensures the
    /// full predicted period block is visible on the ring/strip.
    public var effectiveCycleLength: Int {
        // When period is late, extend calendar to at least today's cycle day
        // so the week strip doesn't cut off before the current date.
        let lateExtension = isLate ? cycleDay : 0

        guard let nextPeriodIn, nextPeriodIn > 0 else {
            return max(cycleLength, lateExtension)
        }
        // nextPeriodIn = days from *today* to prediction start.
        // Predicted period starts on cycle day: cycleDay + nextPeriodIn
        // (e.g. cycleDay 27, nextPeriodIn 2 → predicted period starts day 29)
        // Extend by bleedingDays to include the full predicted block.
        let predictedEndDay = cycleDay + nextPeriodIn + bleedingDays - 1
        return max(cycleLength, predictedEndDay, lateExtension)
    }
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
    /// Period is late — predicted date passed without confirmation
    public let isLate: Bool
    /// How many days late the period is (from today)
    public let daysLate: Int

    /// The date the period was expected to start (only valid when isLate)
    public var expectedPeriodDate: Date? {
        guard isLate, daysLate > 0 else { return nil }
        return cal.date(byAdding: .day, value: -daysLate, to: cal.startOfDay(for: Date()))
    }

    /// How many days late a specific date is relative to expected period.
    /// Positive = late, 0 = expected day, negative = before expected date.
    public func lateness(for date: Date) -> Int? {
        guard let expected = expectedPeriodDate else { return nil }
        return cal.dateComponents([.day], from: expected, to: cal.startOfDay(for: date)).day
    }

    let cal = Calendar.current
    /// Pre-computed sorted anchors for cycleDayInfo (avoids recomputation per call)
    let _sortedAnchors: [Date]

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
        daysUntilOvulation: Int? = nil,
        isLate: Bool = false,
        daysLate: Int = 0
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
        self.isLate = isLate
        self.daysLate = daysLate

        // Pre-compute sorted anchors once (used by cycleDayInfo)
        let cal = Calendar.current
        let startOfCycle = cal.startOfDay(for: cycleStartDate)
        var anchorSet = Set<Date>()
        anchorSet.insert(startOfCycle)
        // Inline allPeriodBlockStarts logic to compute at init time
        // When late, exclude predicted-only days so the predicted block
        // doesn't create a spurious "next cycle" anchor.
        let anchorSourceDays = isLate ? periodDays.subtracting(predictedDays) : periodDays
        if !anchorSourceDays.isEmpty {
            let sorted = anchorSourceDays.sorted()
            var prevKey: String?
            for key in sorted {
                let comps = key.split(separator: "-")
                guard comps.count == 3,
                    let y = Int(comps[0]), let m = Int(comps[1]), let d = Int(comps[2]),
                    let date = cal.date(from: DateComponents(year: y, month: m, day: d))
                else { continue }
                if let pk = prevKey {
                    let prevComps = pk.split(separator: "-")
                    if let py = Int(prevComps[0]), let pm = Int(prevComps[1]), let pd = Int(prevComps[2]),
                        let prevDate = cal.date(from: DateComponents(year: py, month: pm, day: pd))
                    {
                        let gap = cal.dateComponents([.day], from: prevDate, to: date).day ?? 0
                        if gap > 1 { anchorSet.insert(cal.startOfDay(for: date)) }
                    } else {
                        anchorSet.insert(cal.startOfDay(for: date))
                    }
                } else {
                    anchorSet.insert(cal.startOfDay(for: date))
                }
                prevKey = key
            }
        }
        self._sortedAnchors = anchorSet.sorted()
    }

    /// Actual bleeding days derived from server period data (confirmed + predicted).
    /// Tolerates a single-day gap in the period block (server data may have gaps).
    /// Falls back to profile `bleedingDays` when no period data is available.
    public var effectiveBleedingDays: Int {
        guard !periodDays.isEmpty else { return bleedingDays }
        let start = cal.startOfDay(for: cycleStartDate)
        var count = 0
        var gapDays = 0
        for i in 0..<cycleLength {
            guard let date = cal.date(byAdding: .day, value: i, to: start) else { break }
            if periodDays.contains(dateKey(for: date)) {
                count += 1
                gapDays = 0
            } else if count > 0 {
                gapDays += 1
                if gapDays >= 2 { break }
            }
        }
        return max(count, bleedingDays)
}
}
