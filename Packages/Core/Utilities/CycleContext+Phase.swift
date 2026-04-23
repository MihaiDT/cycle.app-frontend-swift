import Foundation

// MARK: - CycleContext › Cycle day + phase resolution

extension CycleContext {
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

    /// Raw days since cycle start — not wrapped, not scaled.
    private func rawDaysSinceCycleStart(for date: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: cycleStartDate), to: cal.startOfDay(for: date)).day ?? 0
    }

    /// Phase for a specific date — menstrual ONLY from server periodDays, never from math.
    public func phase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        // Late check BEFORE fertileDays — predicted fertile days are stale when period is late
        if isLate && rawDaysSinceCycleStart(for: date) >= cycleLength { return .late }
        if fertileDays[dateKey(for: date)] != nil { return .ovulatory }
        guard let info = cycleDayInfo(for: date) else { return nil }
        let p = mathPhase(forCycleDay: info.day, for: date)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for a cycle day number — menstrual ONLY from server periodDays, never from math.
    public func phase(forCycleDay day: Int) -> CyclePhase {
        if isLate && day > cycleLength { return .late }
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

    /// Single source of truth for phase at a given date.
    /// Use this instead of `phase(for:) ?? phase(forCycleDay:)` chains.
    /// Handles late detection correctly even when cycleDayNumber wraps.
    public func resolvedPhase(for date: Date) -> CyclePhase {
        // Late takes highest priority — prevents wrapped cycle days from returning wrong phase
        if isLate && rawDaysSinceCycleStart(for: date) >= cycleLength {
            return .late
        }
        // Menstrual from server data only
        if isPeriodDay(date) { return .menstrual }
        // Ovulatory from server fertile window
        if fertileDays[dateKey(for: date)] != nil { return .ovulatory }
        // Math fallback — guaranteed to return a phase
        let day = cycleDayNumber(for: date) ?? cycleDay
        let p = mathPhase(forCycleDay: day, for: date)
        return p == .menstrual ? .follicular : p
    }

    /// Phase for the dot indicator — same rule: menstrual only from server.
    /// When period is late, shows "late" color instead of menstrual for predicted days.
    public func dotPhase(for date: Date) -> CyclePhase? {
        if isPeriodDay(date) { return .menstrual }
        if isLate && rawDaysSinceCycleStart(for: date) >= cycleLength { return .late }
        if fertileDays[dateKey(for: date)] != nil { return .ovulatory }
        guard let cd = cycleDayNumber(for: date) else { return nil }
        let p = mathPhase(forCycleDay: cd, for: date)
        return p == .menstrual ? .follicular : p
    }
}
