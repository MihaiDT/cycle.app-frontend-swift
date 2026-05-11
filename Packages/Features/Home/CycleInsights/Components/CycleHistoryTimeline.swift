import SwiftUI

// MARK: - Cycle History
//
// Editorial retrospective of logged cycles — each entry reads like a
// page from a diary: length & date range, a warm progress bar showing
// where the period and fertile window fell, and three quiet dot rows
// mapping daily check-in values (energy, mood, sleep) onto the cycle
// days that logged them.
//
// Everything is derived from `JourneyData` which CycleInsightsFeature
// already loads via `menstrualLocal.getJourneyData()`. No new
// persistence, no new round trip.

// MARK: - Timeline model

struct CycleHistoryTimeline: Equatable, Identifiable {
    /// Start-date day key used for both identity and hidden-set lookup.
    let id: String
    let startDate: Date
    let endDate: Date
    let length: Int
    let bleedingDays: Int
    /// Cycle-day (1-based) on which ovulation is modeled. We place it
    /// at `length - 14` — the classic luteal-phase anchor — falling
    /// back to day 14 when the cycle is too short for that math.
    let ovulationDay: Int
    /// Fertile window expressed in cycle-days (1-based, inclusive).
    /// Ovulation day ± 4 / +1, clipped to the cycle.
    let fertileWindow: ClosedRange<Int>
    /// Daily check-in readings keyed by cycle-day (1-based). Missing
    /// days are simply absent from the map — callers render a hollow
    /// circle so "no log" reads as silence, not zero.
    let reports: [Int: JourneyReportInput]
    /// Whether this cycle is the one the user is currently living in.
    let isCurrent: Bool
}

// MARK: - Derivation

enum CycleHistoryBuilder {
    /// Projects a `JourneyData` bundle into render-ready timelines.
    /// Oldest-first order matches how journal entries read top-down.
    static func build(from journey: JourneyData) -> [CycleHistoryTimeline] {
        let sorted = journey.records.sorted { $0.startDate < $1.startDate }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Normalize each report to its local-day start ONCE up front.
        // Previously we re-ran `cal.startOfDay(for:)` inside the per-
        // cycle loop, which is O(cycles × reports) worth of Calendar
        // work on every `journeyLoaded`. Doing it here collapses that
        // to O(reports) and lets each cycle filter a flat tuple list.
        let preppedReports: [(day: Date, input: JourneyReportInput)] = journey.reports.map {
            (cal.startOfDay(for: $0.date), $0)
        }

        return sorted.enumerated().compactMap { idx, record in
            let isLast = idx == sorted.count - 1
            let daysSinceStart = (cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: record.startDate),
                to: today
            ).day ?? 0)

            // A cycle is "in progress" when it's the most recent one
            // logged and no newer period has started yet — regardless
            // of whether the bleed has ended. The menstrual cycle runs
            // from one period start to the next, so the cycle keeps
            // going through the follicular/luteal phases long after
            // the bleed is over. Previously we treated `bleed endDate
            // < today` as "finished", which collapsed the cycle bar
            // to the period length (rendered "6 days · Period: 6 days"
            // for any fresh one-period install).
            let isInProgress = isLast

            // Resolve cycle length:
            //   1. `actualCycleLength` — only set once the NEXT
            //      period confirms (gap-derived).
            //   2. For the ongoing / most-recent cycle, project to the
            //      profile average, stretching past today if the user
            //      is already beyond their typical length.
            //   3. Otherwise the cycle is "orphan" (older record with
            //      no follow-up period to derive a gap) — fall back
            //      to profile average so the bar still renders, but
            //      flagged as in-progress visually isn't appropriate.
            let length: Int
            if let resolved = record.actualCycleLength, resolved > 0 {
                length = resolved
            } else if isInProgress {
                length = max(journey.profileAvgCycleLength, daysSinceStart + 1)
            } else {
                length = journey.profileAvgCycleLength
            }
            guard length > 0 else { return nil }

            let endDate = cal.date(byAdding: .day, value: length - 1, to: record.startDate)
                ?? record.startDate

            // Clamp bleeding days to what could plausibly have been
            // logged so far — a just-started cycle shouldn't render
            // the full profile-avg bleed block as already complete.
            let bleedingDays: Int = {
                if isInProgress {
                    return max(1, min(record.bleedingDays, daysSinceStart + 1))
                }
                return min(record.bleedingDays, length)
            }()

            // Luteal anchor: ovulation sits ~14 days before the next
            // cycle starts. For short/unusual lengths we clamp so the
            // marker stays inside the cycle and never lands on day 1.
            let ovulationDay = max(2, min(length - 14, length - 1))
            let fertileStart = max(1, ovulationDay - 4)
            let fertileEnd = min(length, ovulationDay + 1)
            let fertileWindow = fertileStart...fertileEnd

            let reports = Self.reportsByCycleDay(
                cycleStart: record.startDate,
                length: length,
                preppedReports: preppedReports,
                cal: cal
            )

            let startDateKey = Self.dayKey(record.startDate)

            return CycleHistoryTimeline(
                id: startDateKey,
                startDate: record.startDate,
                endDate: endDate,
                length: length,
                bleedingDays: bleedingDays,
                ovulationDay: ovulationDay,
                fertileWindow: fertileWindow,
                reports: reports,
                isCurrent: isInProgress
            )
        }
    }

    private static func reportsByCycleDay(
        cycleStart: Date,
        length: Int,
        preppedReports: [(day: Date, input: JourneyReportInput)],
        cal: Calendar
    ) -> [Int: JourneyReportInput] {
        let start = cal.startOfDay(for: cycleStart)
        var mapped: [Int: JourneyReportInput] = [:]
        for item in preppedReports {
            guard let diff = cal.dateComponents([.day], from: start, to: item.day).day
            else { continue }
            let cycleDay = diff + 1
            guard cycleDay >= 1 && cycleDay <= length else { continue }
            mapped[cycleDay] = item.input
        }
        return mapped
    }

    /// Shared `yyyy-MM-dd` formatter. `DateFormatter` init is ~1-2ms
    /// and was happening once per cycle per build — hoisting to a
    /// static shaves a meaningful slice off the journey-load path.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        return dayKeyFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
