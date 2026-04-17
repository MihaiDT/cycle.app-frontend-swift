import SwiftUI

// MARK: - Journey Cycle Card

struct JourneyCycleCard: View {
    let summary: JourneyCycleSummary
    let phase: CyclePhase?
    let isFuture: Bool
    let currentDay: Int?

    private var isLate: Bool { phase == .late }

    private var displayPhase: CyclePhase {
        if let phase, phase != .late { return phase }
        if phase == .late { return .luteal }
        let bd = summary.phaseBreakdown
        let maxDays = max(bd.menstrualDays, bd.follicularDays, bd.ovulatoryDays, bd.lutealDays)
        if maxDays == bd.lutealDays { return .luteal }
        if maxDays == bd.ovulatoryDays { return .ovulatory }
        if maxDays == bd.menstrualDays { return .menstrual }
        return .follicular
    }

    private var phaseAccent: Color { displayPhase.orbitColor }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private var monthWatermark: String {
        Self.monthFormatter.string(from: summary.startDate).uppercased()
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var dateRangeText: String {
        let start = Self.dayMonthFormatter.string(from: summary.startDate)
        if summary.isCurrentCycle {
            return "Started \(start)"
        }
        if summary.cycleLength > 0 {
            let cycleEnd = Calendar.current.date(byAdding: .day, value: summary.cycleLength - 1, to: summary.startDate)
            if let cycleEnd {
                return "\(start) - \(Self.dayMonthFormatter.string(from: cycleEnd))"
            }
        }
        return start
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack {
                Spacer()
                Text(monthWatermark)
                    .font(.raleway("Bold", size: 80, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.structure.opacity(isFuture ? 0.06 : 0.10))
                    .offset(x: 8, y: -4)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    let warmBrown = DesignColors.warmBrown
                    Text(topLabel)
                        .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(warmBrown))

                    Spacer()

                    if !isFuture && !summary.isCurrentCycle {
                        HStack(spacing: 4) {
                            Text("Your Recap")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(warmBrown.opacity(0.6))
                    } else if !isFuture && summary.isCurrentCycle {
                        VStack(alignment: .trailing, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                Text("Recap")
                                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                            }
                            Text("When this cycle ends")
                                .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        }
                        .foregroundStyle(DesignColors.textPlaceholder)
                    }
                }

                Spacer()

                Text(titleText)
                    .font(.custom("Raleway-Bold", size: 22, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.raleway("Regular", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .padding(.top, 3)
                }

                Spacer().frame(height: 14)

                if !bottomLabel.isEmpty {
                    Text(bottomLabel)
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(summary.isCurrentCycle ? phaseAccent.opacity(0.6) : DesignColors.textSecondary)
                }
            }
            .padding(AppLayout.spacingL)
        }
        .frame(height: 170)
        .modifier(GlassCardModifier())
        .opacity(isFuture ? 0.6 : 1)
    }

    // MARK: Text

    private var hasMoodData: Bool {
        summary.avgMood != nil && summary.avgEnergy != nil
    }

    private var topLabel: String {
        if isFuture { return "Upcoming" }
        if summary.isCurrentCycle { return "Now" }
        if hasMoodData {
            let name = CycleJourneyEngine.cycleName(for: summary)
            return "\(name) \u{00B7} \(summary.cycleLength) days"
        }
        return "\(summary.cycleLength) days"
    }

    private var titleText: String {
        if isFuture {
            return "~\(Self.dayMonthFormatter.string(from: summary.startDate))"
        }
        return dateRangeText
    }

    private var subtitleText: String {
        if isFuture {
            return "~\(summary.cycleLength) days estimated"
        }
        if summary.isCurrentCycle {
            if isLate {
                let daysLate = (currentDay ?? summary.cycleLength) - summary.cycleLength
                return "\(max(1, daysLate)) days late"
            }
            return ""
        }
        if let reason = CycleJourneyEngine.cycleNameReason(for: summary) {
            return reason
        }
        return "\(summary.bleedingDays) day period"
    }

    private var bottomLabel: String {
        if summary.isCurrentCycle {
            if isLate {
                return "Expected \(max(1, (currentDay ?? summary.cycleLength) - summary.cycleLength)) days ago"
            }
            return "Day \(currentDay ?? summary.cycleLength) \u{00B7} \(displayPhase.displayName)"
        }
        if isFuture {
            return ""
        }
        if let label = summary.accuracyLabel {
            return "Prediction: \(label)"
        }
        return "\(summary.bleedingDays) day period \u{00B7} \(summary.cycleLength) days"
    }
}
