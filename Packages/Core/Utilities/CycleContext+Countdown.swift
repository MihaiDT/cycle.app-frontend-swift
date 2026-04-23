import Foundation

// MARK: - CycleContext › Days until period, fertile window, block helpers

extension CycleContext {

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

    func mathPhase(forCycleDay day: Int, for date: Date? = nil) -> CyclePhase {
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
