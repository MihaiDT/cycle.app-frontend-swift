import SwiftUI
import UIKit

// MARK: - Phase Pill types + decision helpers
//
// Extracted from `CalendarMonthDrawView` so the main view stays focused on
// `draw(_:)`, `configure(month:parent:)`, and tap handling. This extension owns
// the data-shape of pill segments and the per-day decision logic that maps a
// date into a `PillStyle`. Only `drawPill(...)` (CoreGraphics rendering) and
// `pillSegments(...)` (segment building per row) live in the main file.

extension MonthGridDrawView {
    enum PillStyle: Equatable {
        case confirmedPeriod
        case predictedPeriod
        case latePeriod
        case follicular
        case ovulatory
        case luteal
    }

    struct PillSegment {
        let startCol: Int
        let endCol: Int
        let style: PillStyle
        let peakAbsX: CGFloat?
        var continuesLeft: Bool = false
        var continuesRight: Bool = false
    }

    func phaseFor(date: Date) -> CyclePhase? {
        // Use the most recent logged/predicted cycle anchor at or before this date
        // as the phase-calc origin. This snaps phase boundaries onto the user's
        // actual cycle starts instead of drifting from a single global cycleStartDate
        // — eliminates the off-by-1-2-day fragments that appear when logged cycle
        // lengths vary (the audit's known drift issue).
        let target = cal.startOfDay(for: date)
        var bestAnchor: Date? = nil
        for range in cycleRanges where range.start <= target {
            if bestAnchor == nil || range.start > bestAnchor! {
                bestAnchor = range.start
            }
        }
        // For dates inside the first range's backward-extended slot (no real anchor
        // at or before them), walk one cycleLength back from the earliest anchor so
        // phase boundaries still land on logical cycle-start positions.
        if bestAnchor == nil, let earliest = cycleRanges.map(\.start).min() {
            var virtual = earliest
            while virtual > target {
                guard let prev = cal.date(byAdding: .day, value: -cycleLength, to: virtual) else { break }
                virtual = prev
            }
            bestAnchor = virtual
        }
        let anchor = bestAnchor ?? cycleStartDate
        return CalendarFeature.phaseInfo(
            for: date,
            cycleStartDate: anchor,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays
        )?.phase
    }

    /// True if the day immediately before or after `date` is contained in `keys`.
    /// Used to drop isolated single-day entries (period or predicted) that almost
    /// always indicate a data quirk rather than a real run.
    func hasNeighborIn(_ keys: Set<String>, around date: Date) -> Bool {
        if let prev = cal.date(byAdding: .day, value: -1, to: date),
           keys.contains(CalendarFeature.dateKey(prev)) {
            return true
        }
        if let next = cal.date(byAdding: .day, value: 1, to: date),
           keys.contains(CalendarFeature.dateKey(next)) {
            return true
        }
        return false
    }

    /// True if any day within ±(bleedingDays + 1) of the given date is a logged period day.
    /// Used to disambiguate "menstrual phase from cycle-length drift right next to a logged
    /// period" (treat as follicular) from "menstrual phase on a past cycle the user never
    /// logged" (treat as a soft predicted-period pill).
    func hasLoggedPeriodNear(date: Date) -> Bool {
        let window = bleedingDays + 1
        for offset in 1...window {
            for sign in [-1, 1] {
                if let nearby = cal.date(byAdding: .day, value: sign * offset, to: date),
                   periodDays.contains(CalendarFeature.dateKey(nearby)) {
                    return true
                }
            }
        }
        return false
    }

    /// True if the date falls inside any of the precomputed cycle ranges. Each
    /// range stretches from one cycle anchor to the next (or anchor + cycleLength
    /// if no next), with the first range extended one cycleLength backward so the
    /// previous cycle's luteal end stays coloured. Together the ranges fill every
    /// day inside the user's logged horizon — no gaps between adjacent cycles.
    func isInLoggedCycleRange(date: Date) -> Bool {
        let target = cal.startOfDay(for: date)
        for range in cycleRanges {
            if target >= range.start && target < range.end {
                return true
            }
        }
        return false
    }

    func pillStyle(forDay date: Date, key: String) -> PillStyle? {
        // periodDays now contains only logged entries (predicted_period was split
        // out into predictedPeriodDays alone in parseCalendarEntries). So presence
        // in periodDays is the source of truth for "user logged this day".
        let isConfirmed = periodDays.contains(key)
        let isPredicted = predictedPeriodDays.contains(key) && !isConfirmed
        let isInLate: Bool = {
            guard isLate, let pred = predictedDate else { return false }
            guard let diff = cal.dateComponents([.day], from: cal.startOfDay(for: pred), to: cal.startOfDay(for: date)).day else { return false }
            return diff >= -1 && diff < cycleLength
        }()

        if isConfirmed { return .confirmedPeriod }
        if isInLate && isPredicted { return .latePeriod }
        // Predicted-period pills only render when (a) part of a multi-day run AND
        // (b) no logged period in the same neighbourhood. Single isolated entries
        // are server-side quirks; predicted entries adjacent to a logged period
        // are stale predictions superseded by the actual log — both must fall
        // through to phase logic so the row reads as one continuous segment
        // instead of fragmenting into stripe + cream + cream pills.
        let today = cal.startOfDay(for: Date())
        if isPredicted,
           hasNeighborIn(predictedPeriodDays, around: date),
           !hasLoggedPeriodNear(date: date),
           cal.startOfDay(for: date) >= today {
            return .predictedPeriod
        }
        // Fertile band: sourced from the entries layer so the span
        // matches across ON/OFF. ON paints the same days peach, OFF
        // blanks them — band length is identical either way.
        if ovulationDays.contains(key) || fertileDays[key] != nil {
            return showFertileWindow ? .ovulatory : nil
        }

        // Phase pills only render inside an anchored cycle: a `[start, start + cycleLength)`
        // window beginning on each logged or predicted period start. Outside any such
        // window we render nothing — old unlogged months and far-future months stay empty.
        guard isInLoggedCycleRange(date: date) else { return nil }

        switch phaseFor(date: date) {
        case .follicular: return .follicular
        case .luteal: return .luteal
        case .ovulatory: return showFertileWindow ? .ovulatory : nil
        // Unmarked menstrual phase has four fallbacks:
        // - Day directly before a logged period start → late luteal / PMS, fall back
        //   to luteal so the run from luteal into period stays unbroken.
        // - Near a logged period (within bleedingDays+1) → boundary drift on the
        //   post-period side, fall back to follicular.
        // - Far from any logged period AND in the future → projected upcoming
        //   period the user hasn't confirmed; show as predictedPeriod stripe.
        // - Far from any logged period AND in the past → empty (don't fabricate
        //   past period guesses; only show what the user actually logged).
        case .menstrual:
            if let next = cal.date(byAdding: .day, value: 1, to: date),
               periodDays.contains(CalendarFeature.dateKey(next)) {
                return .luteal
            }
            if hasLoggedPeriodNear(date: date) { return .follicular }
            if cal.startOfDay(for: date) >= today { return .predictedPeriod }
            return nil
        case .late, .none: return nil
        }
    }

    func pillSegments(forRow row: Int, info: MonthGridRenderer.GridInfo, cellW: CGFloat) -> [PillSegment] {
        var segs: [PillSegment] = []
        var col = 0
        while col < 7 {
            let slot = row * 7 + col
            let day = slot - info.offset + 1
            guard day >= 1, day <= info.daysInMonth,
                  let date = cal.date(byAdding: .day, value: day - 1, to: info.firstOfMonth) else {
                col += 1
                continue
            }
            let key = info.keyPrefix + String(format: "%02d", day)
            guard let style = pillStyle(forDay: date, key: key) else {
                col += 1
                continue
            }

            var end = col
            while end + 1 < 7 {
                let nslot = row * 7 + (end + 1)
                let nday = nslot - info.offset + 1
                guard nday >= 1, nday <= info.daysInMonth,
                      let ndate = cal.date(byAdding: .day, value: nday - 1, to: info.firstOfMonth) else { break }
                let nkey = info.keyPrefix + String(format: "%02d", nday)
                guard pillStyle(forDay: ndate, key: nkey) == style else { break }
                end += 1
            }

            var peakAbsX: CGFloat? = nil
            if style == .ovulatory {
                for k in col...end {
                    let kslot = row * 7 + k
                    let kday = kslot - info.offset + 1
                    let kkey = info.keyPrefix + String(format: "%02d", kday)
                    if ovulationDays.contains(kkey) {
                        peakAbsX = horizontalInset + CGFloat(k) * cellW + cellW / 2
                        break
                    }
                }
            }

            segs.append(PillSegment(startCol: col, endCol: end, style: style, peakAbsX: peakAbsX))
            col = end + 1
        }
        return segs
    }
}
