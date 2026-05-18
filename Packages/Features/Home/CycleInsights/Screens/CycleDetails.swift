import SwiftUI

// MARK: - Cycle Details
//
// Apple Health–style detail screen pushed when the user taps a row
// in the compact Cycle History card or the full History archive.
// Stacked white cards on the warm peach backdrop, each with a caps
// eyebrow header. The cycle length / period length cards are
// tappable as a whole — `info.circle` top-right signals "open
// explainer" (not "drill into a sibling page"), since the tap
// opens a copy sheet about the metric, not another row in a list.

struct CycleDetailsView: View {
    let timeline: CycleHistoryTimeline
    let onStatInfoTap: (CycleStatInfoKind) -> Void

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        // Same shell as Cycle Stats: warm peach `AppleHealthBackground`
        // edge-to-edge behind the cards (under nav bar + home indicator),
        // ScrollView inside the safe area so the first card sits cleanly
        // below the nav bar instead of slipping under it. Cycle Stats
        // gets away with `.ignoresSafeArea` on its scroll surface because
        // `UICollectionView` auto-pads the top by the nav bar height —
        // SwiftUI's `ScrollView` doesn't, and content disappears behind
        // the translucent header if you try the same trick here.
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                    summaryCard
                    if timeline.isCurrent {
                        inProgressCard
                    } else {
                        cycleLengthCard
                        periodLengthCard
                    }
                    if !timeline.reports.isEmpty {
                        CycleDetailsCheckInsCard(timeline: timeline)
                    }
                    momentsCard
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingL)
                .padding(.bottom, AppLayout.spacingXXL)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Cycle Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text("DATE RANGE")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Text(summaryRange)
                .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            CycleHistoryBar(timeline: timeline)
                .padding(.top, 4)

            CycleHistoryBarLegend()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    private var summaryRange: String {
        let start = Self.rangeFormatter.string(from: timeline.startDate)
        if timeline.isCurrent {
            return "Current cycle · from \(start)"
        }
        let end = Self.rangeFormatter.string(from: timeline.endDate)
        return "\(start) – \(end)"
    }

    // MARK: - In-progress placeholder

    @ViewBuilder
    private var inProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text("CYCLE IN PROGRESS")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Text("Length figures appear once this cycle closes. Until then, the numbers would still be a projection.")
                .font(.raleway("Regular", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Stat cards

    @ViewBuilder
    private var cycleLengthCard: some View {
        let badge = CycleNormality.classifyCycleLength(days: timeline.length)
        statCard(
            iconName: "circle.dashed",
            title: "Cycle length",
            value: "\(timeline.length) \(timeline.length == 1 ? "day" : "days")",
            badge: badge,
            description: cycleLengthCopy(badge: badge),
            onInfoTap: { onStatInfoTap(.cycleLength) }
        )
    }

    private func cycleLengthCopy(badge: CycleStatusBadge) -> String {
        switch badge.tone {
        case .normal:
            return "This cycle ran inside the typical range of \(CycleNormality.cycleLengthNormalMin)–\(CycleNormality.cycleLengthNormalMax) days."
        case .needsAttention:
            return "This cycle ran outside the typical range of \(CycleNormality.cycleLengthNormalMin)–\(CycleNormality.cycleLengthNormalMax) days. Occasional outliers are expected, but a pattern is worth noticing."
        }
    }

    @ViewBuilder
    private var periodLengthCard: some View {
        let badge = CycleNormality.classifyPeriodLength(days: timeline.bleedingDays)
        statCard(
            iconName: "drop",
            title: "Period length",
            value: "\(timeline.bleedingDays) \(timeline.bleedingDays == 1 ? "day" : "days")",
            badge: badge,
            description: periodLengthCopy(badge: badge),
            onInfoTap: { onStatInfoTap(.periodLength) }
        )
    }

    private func periodLengthCopy(badge: CycleStatusBadge) -> String {
        switch badge.tone {
        case .normal:
            return "This bleed ran inside the typical range of \(CycleNormality.periodLengthNormalMin)–\(CycleNormality.periodLengthNormalMax) days."
        case .needsAttention:
            return "This bleed ran outside the typical range of \(CycleNormality.periodLengthNormalMin)–\(CycleNormality.periodLengthNormalMax) days. Occasional outliers are expected, but a pattern is worth noticing."
        }
    }

    // MARK: - Stat card builder

    @ViewBuilder
    private func statCard(
        iconName: String,
        title: String,
        value: String,
        badge: CycleStatusBadge,
        description: String,
        onInfoTap: @escaping () -> Void
    ) -> some View {
        Button(action: onInfoTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DesignColors.textSecondary)
                    Text(title.uppercased())
                        .font(AppTypography.cardEyebrow)
                        .tracking(1.4)
                        .foregroundStyle(DesignColors.textSecondary)
                    Spacer(minLength: 8)
                    // The card opens an explainer sheet, not a drill-
                    // down list — info glyph reads more honestly than
                    // a chevron right (which signals "navigate to a
                    // sibling page").
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(value)
                        .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                        .tracking(-0.5)
                        .foregroundStyle(DesignColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 8)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(badgeDotColor(for: badge.tone))
                            .frame(width: 6, height: 6)
                        Text(badge.label.lowercased())
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .tracking(0.4)
                            .foregroundStyle(badgeTextColor(for: badge.tone))
                    }
                }

                Text(description)
                    .font(.raleway("Regular", size: 14, relativeTo: .callout))
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: 28)
        .accessibilityLabel("\(title), \(value), \(badge.label.lowercased())")
        .accessibilityHint("Opens an explainer for \(title.lowercased())")
    }

    private func badgeDotColor(for tone: CycleStatusTone) -> Color {
        switch tone {
        case .normal:         return DesignColors.statusSuccess
        case .needsAttention: return DesignColors.accentHoney
        }
    }

    private func badgeTextColor(for tone: CycleStatusTone) -> Color {
        switch tone {
        case .normal:         return DesignColors.statusSuccess
        case .needsAttention: return DesignColors.accentHoneyText
        }
    }

    // MARK: - Key moments

    @ViewBuilder
    private var momentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text("KEY MOMENTS")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                momentRow(
                    tint: CyclePhase.menstrual.orbitColor,
                    label: "Period",
                    text: periodMomentText
                )

                Divider()
                    .background(DesignColors.text.opacity(DesignColors.dividerOpacity))

                momentRow(
                    tint: CyclePhase.ovulatory.orbitColor.opacity(0.7),
                    label: "Fertile",
                    text: fertileMomentText
                )

                Divider()
                    .background(DesignColors.text.opacity(DesignColors.dividerOpacity))

                momentRow(
                    tint: CyclePhase.ovulatory.orbitColor,
                    label: "Ovulation",
                    text: ovulationMomentText,
                    isRing: true
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    @ViewBuilder
    private func momentRow(
        tint: Color,
        label: String,
        text: String,
        isRing: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack {
                if isRing {
                    Circle()
                        .stroke(tint, lineWidth: 1.4)
                        .frame(width: 10, height: 10)
                } else {
                    PhaseGlossyDot(tint: tint, size: 10)
                }
            }
            .frame(width: 14)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(DesignColors.textSecondary)
                Text(text)
                    .font(.raleway("Medium", size: 14, relativeTo: .callout))
                    .foregroundStyle(DesignColors.text.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }

    private var periodMomentText: String {
        let cal = Calendar.current
        let start = Self.longFormatter.string(from: timeline.startDate)
        let endDay = cal.date(
            byAdding: .day,
            value: max(0, timeline.bleedingDays - 1),
            to: timeline.startDate
        ) ?? timeline.startDate
        let end = Self.longFormatter.string(from: endDay)
        if timeline.isCurrent {
            return "Started \(start)."
        }
        if timeline.bleedingDays <= 1 {
            return "Started \(start)."
        }
        return "Ran from \(start) to \(end)."
    }

    private var fertileMomentText: String {
        let cal = Calendar.current
        let startDay = cal.date(
            byAdding: .day,
            value: timeline.fertileWindow.lowerBound - 1,
            to: timeline.startDate
        ) ?? timeline.startDate
        let endDay = cal.date(
            byAdding: .day,
            value: timeline.fertileWindow.upperBound - 1,
            to: timeline.startDate
        ) ?? timeline.startDate
        let start = Self.longFormatter.string(from: startDay)
        let end = Self.longFormatter.string(from: endDay)
        if timeline.isCurrent {
            return "Window expected between \(start) and \(end)."
        }
        return "Window likely ran from \(start) to \(end)."
    }

    private var ovulationMomentText: String {
        let cal = Calendar.current
        let day = cal.date(
            byAdding: .day,
            value: timeline.ovulationDay - 1,
            to: timeline.startDate
        ) ?? timeline.startDate
        let label = Self.longFormatter.string(from: day)
        if timeline.isCurrent {
            return "Expected around \(label)."
        }
        return "Likely on \(label)."
    }
}
