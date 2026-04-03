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

    private let cal = Calendar.current
    /// Pre-computed sorted anchors for cycleDayInfo (avoids recomputation per call)
    private let _sortedAnchors: [Date]

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

    // MARK: - Date Key (thread-safe, no DateFormatter)

    public func dateKey(for date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Period Detection (server only)

    public func isPeriodDay(_ date: Date) -> Bool {
        let key = dateKey(for: date)
        let isOnlyPredicted = predictedDays.contains(key)
            && !periodDays.subtracting(predictedDays).contains(key)
        if isOnlyPredicted {
            // When period is late, skip predicted days in the CURRENT late window only
            // (not future cycle predictions which are still valid)
            if isLate {
                if let lateness = lateness(for: date), lateness >= -1, lateness < cycleLength {
                    return false
                }
                // Future cycle predictions are still valid period days
            }
            // Past predicted days that weren't confirmed → not period days
            let today = cal.startOfDay(for: Date())
            if cal.startOfDay(for: date) < today { return false }
        }
        return periodDays.contains(key)
    }

    public func isPredictedDay(_ date: Date) -> Bool {
        let key = dateKey(for: date)
        guard predictedDays.contains(key) else { return false }
        // When period is late, don't show predicted days in the current late window
        if isLate {
            if let lateness = lateness(for: date), lateness >= -1, lateness < cycleLength {
                return false
            }
            // Future cycle predictions are still valid
        }
        // Past predicted days that weren't confirmed → hidden
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: date)
        if d < today { return false }
        return true
    }

    public func isConfirmedPeriod(_ date: Date) -> Bool {
        let key = dateKey(for: date)
        return periodDays.contains(key) && !predictedDays.contains(key)
    }

    /// True when date is a predicted period day (today or future, not confirmed)
    public func isPredictedOnly(_ date: Date) -> Bool {
        isPredictedDay(date) && !isConfirmedPeriod(date)
    }

    /// True when the current cycle has at least one confirmed (non-predicted) period day.
    /// When this is true, the period already happened and the cycle is NOT late.
    /// Only checks days on or after cycleStartDate to avoid false positives from previous cycles.
    public var hasConfirmedPeriodInCurrentCycle: Bool {
        let start = cal.startOfDay(for: cycleStartDate)
        let confirmedDays = periodDays.subtracting(predictedDays)
        return confirmedDays.contains { key in
            guard let date = Self.dateFormatter.date(from: key) else { return false }
            return cal.startOfDay(for: date) >= start
        }
    }

    /// Frontend-side late period detection — catches cases the backend may miss.
    /// True when predicted period days exist in the past but none are confirmed.
    public var isPeriodLateOrMissing: Bool {
        if isLate { return true }
        guard !hasConfirmedPeriodInCurrentCycle else { return false }
        let today = cal.startOfDay(for: Date())
        let hasPastPredicted = predictedDays.contains(where: { key in
            guard let date = Self.dateFormatter.date(from: key) else { return false }
            return cal.startOfDay(for: date) < today
        })
        return hasPastPredicted
    }

    /// Days late — frontend calculation when backend doesn't provide it.
    public var effectiveDaysLate: Int {
        if daysLate > 0 { return daysLate }
        guard isPeriodLateOrMissing else { return 0 }
        let today = cal.startOfDay(for: Date())
        // Find the earliest predicted day in the past
        let pastPredictedDates = predictedDays.compactMap { key -> Date? in
            guard let date = Self.dateFormatter.date(from: key) else { return nil }
            let d = cal.startOfDay(for: date)
            return d < today ? d : nil
        }
        guard let earliest = pastPredictedDates.min() else { return 0 }
        return cal.dateComponents([.day], from: earliest, to: today).day ?? 0
    }

    /// The date the period was expected — works with both backend and frontend detection.
    public var effectiveExpectedDate: Date? {
        if let d = expectedPeriodDate { return d }
        guard isPeriodLateOrMissing else { return nil }
        let today = cal.startOfDay(for: Date())
        return predictedDays.compactMap { key -> Date? in
            guard let date = Self.dateFormatter.date(from: key) else { return nil }
            let d = cal.startOfDay(for: date)
            return d < today ? d : nil
        }.min()
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    /// True when date is a predicted period day in the late window (hidden by isPeriodDay/isPredictedDay).
    /// Use this to still show these days visually on calendars with dashed styling.
    public func isLatePrediction(_ date: Date) -> Bool {
        guard isLate else { return false }
        let key = dateKey(for: date)
        guard predictedDays.contains(key) else { return false }
        guard !periodDays.subtracting(predictedDays).contains(key) else { return false }
        if let l = lateness(for: date), l >= -1, l < cycleLength { return true }
        return false
    }

    // MARK: - Cycle Day Calculation

    /// Cycle day number (1-based) and offset (0=current cycle, 1=next, etc.)
    public func cycleDayInfo(for date: Date) -> (day: Int, offset: Int)? {
        let d = cal.startOfDay(for: date)
        let startOfCycle = cal.startOfDay(for: cycleStartDate)
        guard cycleLength > 0 else { return nil }

        let anchors = _sortedAnchors

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
        // Check calendar fertile days directly
        if fertileDays[dateKey(for: date)] != nil { return .ovulatory }
        guard let info = cycleDayInfo(for: date) else { return nil }
        let p = mathPhase(forCycleDay: info.day, for: date)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for a cycle day number — menstrual ONLY from server periodDays, never from math.
    public func phase(forCycleDay day: Int) -> CyclePhase {
        let date = cal.date(byAdding: .day, value: day - 1, to: cal.startOfDay(for: cycleStartDate))
        if let date, isPeriodDay(date) {
            return .menstrual
        }
        if let date, fertileDays[dateKey(for: date)] != nil {
            return .ovulatory
        }
        let p = mathPhase(forCycleDay: day, for: date)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for the dot indicator — same rule: menstrual only from server.
    /// When period is late, shows "late" color instead of menstrual for predicted days.
    public func dotPhase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        if fertileDays[dateKey(for: date)] != nil { return .ovulatory }
        guard let cd = cycleDayNumber(for: date) else { return nil }
        let p = mathPhase(forCycleDay: cd, for: date)
        return p == .menstrual ? .follicular : p
    }

    // MARK: - Days Until Next Period

    /// Days until next period from a given display day (searches server calendar entries).
    /// Searches up to 2× cycleLength to handle irregular cycles. Never returns negative.
    /// Anchors from cycleStartDate (same as phase(forCycleDay:)) to avoid timezone mismatch.
    public func daysUntilPeriod(fromCycleDay displayDay: Int) -> Int {
        let startOfCycle = cal.startOfDay(for: cycleStartDate)
        if !periodDays.isEmpty {
            let displayDate = cal.date(byAdding: .day, value: displayDay - 1, to: startOfCycle)
                ?? cal.startOfDay(for: Date())
            let searchLimit = cycleLength * 2

            for i in 1...searchLimit {
                if let futureDate = cal.date(byAdding: .day, value: i, to: displayDate) {
                    // Use isPeriodDay to respect late state (skips predicted days when late)
                    if isPeriodDay(futureDate) {
                        return i
                    }
                }
            }
        }
        if let nextPeriodIn, nextPeriodIn > 0 {
            let dayOffset = displayDay - cycleDay
            return max(0, nextPeriodIn - dayOffset)
        }
        return max(0, effectiveCycleLength - displayDay + 1)
    }

    /// Days until next period from a specific date (accurate for any cycle offset).
    /// Searches up to 2× cycleLength to handle irregular cycles. Never returns negative.
    public func daysUntilPeriod(from date: Date) -> Int {
        let d = cal.startOfDay(for: date)
        if !periodDays.isEmpty {
            let searchLimit = cycleLength * 2

            for i in 1...searchLimit {
                if let futureDate = cal.date(byAdding: .day, value: i, to: d) {
                    // Use isPeriodDay to respect late state (skips predicted days when late)
                    if isPeriodDay(futureDate) {
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

    // MARK: - Fertile Window Day Range

    /// Fertile window as cycle-day range for a specific date's cycle.
    /// Looks up the ovulation day from `ovulationDays` (calendar API) that belongs
    /// to the same cycle as `date`, then computes Wilcox window (ov-5 to ov+1).
    /// Falls back to prediction peak, then math formula.
    public func fertileWindowDayRange(for date: Date) -> ClosedRange<Int> {
        // Find the cycle anchor (period block start) for this date
        if let info = cycleDayInfo(for: date) {
            let anchor = cal.date(byAdding: .day, value: -(info.day - 1), to: cal.startOfDay(for: date))!
            // Search ovulationDays within this cycle
            for dayOffset in 0..<cycleLength {
                if let d = cal.date(byAdding: .day, value: dayOffset, to: anchor) {
                    if ovulationDays.contains(dateKey(for: d)) {
                        let ovDay = dayOffset + 1
                        return max(1, ovDay - 5)...min(cycleLength, ovDay + 1)
                    }
                }
            }
        }
        // Fallback: prediction peak for current cycle
        if let peak = fertileWindowPeak {
            let start = cal.startOfDay(for: cycleStartDate)
            let peakDay = (cal.dateComponents([.day], from: start, to: cal.startOfDay(for: peak)).day ?? -1) + 1
            if peakDay >= 1, peakDay <= cycleLength {
                return max(1, peakDay - 5)...min(cycleLength, peakDay + 1)
            }
        }
        // Final fallback: math formula
        let ovDay = max(10, cycleLength - 14)
        return max(1, ovDay - 5)...min(cycleLength, ovDay + 1)
    }

    /// Default fertile window (for today / current cycle)
    public var fertileWindowDayRange: ClosedRange<Int> {
        fertileWindowDayRange(for: Date())
    }

    // MARK: - Private

    private func mathPhase(forCycleDay day: Int, for date: Date? = nil) -> CyclePhase {
        let fw = date.map { fertileWindowDayRange(for: $0) } ?? fertileWindowDayRange
        let bd = min(max(1, bleedingDays), cycleLength)
        if day >= 1 && day <= bd { return .menstrual }
        if day < fw.lowerBound { return .follicular }
        if fw.contains(day) { return .ovulatory }
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
    /// Skips past predicted-only days that weren't confirmed.
    public func periodBlockDay(for date: Date) -> Int? {
        let d = cal.startOfDay(for: date)
        guard isPeriodDay(d) else { return nil }
        var start = d
        for i in 1...10 {
            guard let prev = cal.date(byAdding: .day, value: -i, to: d) else { break }
            if isPeriodDay(prev) {
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
            daysUntilOvulation: status.fertileWindow?.daysUntilPeak,
            isLate: status.nextPrediction?.isLate ?? false,
            daysLate: status.nextPrediction?.daysLate ?? 0
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
