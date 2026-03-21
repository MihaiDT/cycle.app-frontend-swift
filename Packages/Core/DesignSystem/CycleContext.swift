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
        let startOfCycle = cal.startOfDay(for: cycleStartDate)
        guard cycleLength > 0 else { return nil }

        // Build sorted anchors from ALL period block starts (confirmed + predicted)
        // plus the current cycleStartDate.
        var anchorSet = Set<Date>()
        anchorSet.insert(startOfCycle)
        for s in allPeriodBlockStarts() {
            anchorSet.insert(cal.startOfDay(for: s))
        }
        let anchors = anchorSet.sorted()

        // Find which anchor-based cycle this date belongs to
        for i in (0..<anchors.count).reversed() {
            let anchor = anchors[i]
            let diff = cal.dateComponents([.day], from: anchor, to: d).day ?? 0
            guard diff >= 0 else { continue }

            let nextAnchor = i + 1 < anchors.count ? anchors[i + 1] : nil
            let gapToNext = nextAnchor.flatMap { cal.dateComponents([.day], from: anchor, to: $0).day } ?? cycleLength

            guard diff < gapToNext else { continue }

            let rawDay = diff + 1
            let scaledDay: Int
            if gapToNext != cycleLength && gapToNext > 0 {
                scaledDay = max(
                    1,
                    min(Int(round(Double(rawDay) * Double(cycleLength) / Double(gapToNext))), cycleLength)
                )
            } else {
                scaledDay = min(rawDay, cycleLength)
            }

            // Offset: 0 for the anchor that matches cycleStartDate, negative for past, positive for future
            let anchorDiff = cal.dateComponents([.day], from: startOfCycle, to: anchor).day ?? 0
            let offset: Int
            if anchorDiff == 0 {
                offset = 0
            } else if anchorDiff < 0 {
                offset = anchorDiff / cycleLength - (anchorDiff % cycleLength == 0 ? 0 : 1)
            } else {
                offset = anchorDiff / cycleLength + (anchorDiff % cycleLength == 0 ? 0 : 1)
            }
            return (scaledDay, offset)
        }

        // Date is before all known anchors → modular from earliest anchor
        if let firstAnchor = anchors.first {
            let diff = cal.dateComponents([.day], from: firstAnchor, to: d).day ?? 0
            if diff < 0 {
                let mod = ((diff % cycleLength) + cycleLength) % cycleLength
                return (mod + 1, diff / cycleLength - (diff % cycleLength == 0 ? 0 : 1))
            }
        }

        // Fallback: date beyond all anchors → modular from last anchor
        if let lastAnchor = anchors.last {
            let diff = cal.dateComponents([.day], from: lastAnchor, to: d).day ?? 0
            let day = (diff % cycleLength) + 1
            return (day, anchors.count - 1 + diff / cycleLength)
        }
        let daysDiff = cal.dateComponents([.day], from: startOfCycle, to: d).day ?? 0
        return (daysDiff % cycleLength + 1, daysDiff / cycleLength)
    }

    /// Just the cycle day number for a date
    public func cycleDayNumber(for date: Date) -> Int? {
        cycleDayInfo(for: date)?.day
    }

    // MARK: - Phase Resolution (server-only menstrual, math for other phases)

    /// Phase for a specific date — menstrual ONLY from server periodDays, never from math.
    public func phase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        guard let info = cycleDayInfo(for: date) else { return nil }
        let p = mathPhase(forCycleDay: info.day)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for a cycle day number — menstrual ONLY from server periodDays, never from math.
    public func phase(forCycleDay day: Int) -> CyclePhase {
        if let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycleStartDate)) {
            if periodDays.contains(dateKey(for: date)) {
                return .menstrual
            }
        }
        let p = mathPhase(forCycleDay: day)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for the dot indicator — same rule: menstrual only from server.
    public func dotPhase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        guard let cd = cycleDayNumber(for: date) else { return nil }
        let p = mathPhase(forCycleDay: cd)
        return p == .menstrual ? .follicular : p
    }

    // MARK: - Days Until Next Period

    /// Days until next period from a given display day (searches server calendar entries).
    /// Searches up to 2× cycleLength to handle irregular cycles. Never returns negative.
    public func daysUntilPeriod(fromCycleDay displayDay: Int) -> Int {
        if !periodDays.isEmpty {
            let today = cal.startOfDay(for: Date())
            let dayOffset = displayDay - cycleDay
            let displayDate = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
            let searchLimit = cycleLength * 2

            for i in 1...searchLimit {
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
        return max(0, cycleLength - displayDay + 1)
    }

    /// Days until next period from a specific date (accurate for any cycle offset).
    /// Searches up to 2× cycleLength to handle irregular cycles. Never returns negative.
    public func daysUntilPeriod(from date: Date) -> Int {
        let d = cal.startOfDay(for: date)
        if !periodDays.isEmpty {
            let searchLimit = cycleLength * 2

            for i in 1...searchLimit {
                if let futureDate = cal.date(byAdding: .day, value: i, to: d) {
                    if periodDays.contains(dateKey(for: futureDate)) {
                        return i
                    }
                }
            }
        }
        // Fallback: use cycle day math
        if let info = cycleDayInfo(for: d) {
            return max(0, cycleLength - info.day + 1)
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

    /// All period block start dates (confirmed + predicted), sorted chronologically.
    private func allPeriodBlockStarts() -> [Date] {
        guard !periodDays.isEmpty else { return [] }
        let sorted = periodDays.sorted()
        var starts: [Date] = []
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
                    if gap > 1 { starts.append(date) }
                } else {
                    starts.append(date)
                }
            } else {
                starts.append(date)
            }
            prevKey = key
        }
        return starts
    }

    /// All predicted period block start dates, sorted chronologically.
    private func predictedBlockStarts() -> [Date] {
        guard !predictedDays.isEmpty else { return [] }
        let sorted = predictedDays.sorted()
        var starts: [Date] = []
        var prevKey: String?
        for key in sorted {
            let comps = key.split(separator: "-")
            guard comps.count == 3,
                let y = Int(comps[0]), let m = Int(comps[1]), let d = Int(comps[2]),
                let date = cal.date(from: DateComponents(year: y, month: m, day: d))
            else { continue }
            if let pk = prevKey {
                // Check if previous day was also predicted
                let prevComps = pk.split(separator: "-")
                if let py = Int(prevComps[0]), let pm = Int(prevComps[1]), let pd = Int(prevComps[2]),
                    let prevDate = cal.date(from: DateComponents(year: py, month: pm, day: pd))
                {
                    let gap = cal.dateComponents([.day], from: prevDate, to: date).day ?? 0
                    if gap > 1 { starts.append(date) }
                } else {
                    starts.append(date)
                }
            } else {
                starts.append(date)
            }
            prevKey = key
        }
        return starts
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
        if let daysUntil = status.nextPrediction?.daysUntil,
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

        let phase =
            CyclePhase(rawValue: status.currentCycle.phase)
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
