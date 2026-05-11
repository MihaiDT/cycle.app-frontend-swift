import SwiftUI

// MARK: - Cycle Stats Today Header
//
// Single editorial sentence that pins the user to "where am I in
// my cycle right now" before the screen plonges into the stats
// cards. Sits in `CycleStatsCardList.leadingContent` slot — above
// the first card, below the nav bar — so the answer to "today?"
// is the first thing the eye lands on.
//
// Format: `Day {n}. {phase} phase. {countdown}.`
//
// Countdown variants (priority order):
//   1. Late period      → "Period {n} days late."
//   2. Period active    → "Day {n} of your period." or "Last day of your period."
//   3. Fertile peak     → "Ovulation today." / "Ovulation in {n} days."
//   4. Fertile active   → "Fertile window: {n} more day{s}."
//   5. Default          → "Next period in {n} days."
//
// Visual: no card surface, no chrome — just type. Reads as a
// continuation of the nav title, not as another data tile. The
// rest of the screen (rings cards, trend chart) carries the
// surface weight; this line carries the meaning.

struct CycleStatsTodayHeader: View {
    let context: CycleContext

    var body: some View {
        Text(formatted)
            .font(.raleway("Medium", size: 15, relativeTo: .body))
            .tracking(-0.1)
            .foregroundStyle(DesignColors.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
            .accessibilityLabel(accessibilityLine)
    }

    // MARK: - Copy

    /// Sentence-line-broken copy so the cycle anchor reads as one
    /// breath ("Day 22.") then the body context ("Luteal phase.")
    /// then the forward-looking part ("Next period in 6 days.").
    /// Same cadence the rest of the editorial cards use.
    private var formatted: String {
        [
            dayLine,
            phaseLine,
            countdownLine
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private var dayLine: String? {
        guard context.cycleDay > 0 else { return nil }
        return "Day \(context.cycleDay)."
    }

    private var phaseLine: String? {
        let name = displayName(for: context.currentPhase)
        return "\(name.capitalized) phase."
    }

    private var countdownLine: String? {
        // 1. Late period — flag honestly, no fake confidence.
        if context.isLate, context.daysLate > 0 {
            return context.daysLate == 1
                ? "Period 1 day late."
                : "Period \(context.daysLate) days late."
        }

        // 2. Period currently active — count from cycle day 1.
        let bleeding = context.bleedingDays
        if bleeding > 0, context.cycleDay >= 1, context.cycleDay <= bleeding {
            if context.cycleDay == bleeding {
                return "Last day of your period."
            }
            return context.cycleDay == 1
                ? "Day one of your period."
                : "Day \(context.cycleDay) of your period."
        }

        // 3. Ovulation imminent — most-relevant date in fertile window.
        if let untilOv = context.daysUntilOvulation {
            if untilOv == 0 { return "Ovulation today." }
            if untilOv == 1 { return "Ovulation tomorrow." }
            if untilOv > 0 { return "Ovulation in \(untilOv) days." }
        }

        // 4. Fertile window active (no peak signal handy) — soft window framing.
        if context.fertileWindowActive,
           let end = context.fertileWindowEnd {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let endDay = cal.startOfDay(for: end)
            let daysLeft = cal.dateComponents([.day], from: today, to: endDay).day ?? 0
            if daysLeft <= 0 { return "Last day of your fertile window." }
            if daysLeft == 1 { return "Fertile window: 1 more day." }
            return "Fertile window: \(daysLeft) more days."
        }

        // 5. Default — countdown to predicted next period.
        if let untilPeriod = context.nextPeriodIn {
            if untilPeriod == 0 { return "Period likely today." }
            if untilPeriod == 1 { return "Next period tomorrow." }
            if untilPeriod > 0 { return "Next period in \(untilPeriod) days." }
        }

        return nil
    }

    /// Lowercase phase name mid-sentence per cycle.app voice.
    /// `.late` is a tracking state (period overdue), not a hormonal
    /// phase — frame it as luteal so the reader doesn't see a name
    /// they don't recognise on the most-prominent line of the screen.
    private func displayName(for phase: CyclePhase) -> String {
        switch phase {
        case .menstrual:  return "menstrual"
        case .follicular: return "follicular"
        case .ovulatory:  return "ovulatory"
        case .luteal:     return "luteal"
        case .late:       return "late luteal"
        }
    }

    private var accessibilityLine: String {
        formatted.replacingOccurrences(of: "\n", with: " ")
    }
}
