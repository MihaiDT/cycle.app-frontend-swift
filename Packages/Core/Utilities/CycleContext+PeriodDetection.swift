import Foundation

// MARK: - CycleContext › Period detection

extension CycleContext {

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
        // When period is late, show ALL predicted days (past and future)
        // so the user can see when the period was expected
        if isLate { return true }
        // Normal cycle: hide past predicted days that weren't confirmed
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

}
