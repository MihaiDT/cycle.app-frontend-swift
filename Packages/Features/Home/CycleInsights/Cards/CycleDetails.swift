import SwiftUI

// MARK: - Cycle Details
//
// Presented as a sheet when the user taps a row in either the
// compact Cycle History card or the full History archive. Mirrors
// the information density of Flo/Lively's cycle-details page but in
// cycle.app's voice and palette — clinical facts without the
// diagnostic tone.

struct CycleDetailsView: View {
    let timeline: CycleHistoryTimeline
    let onDismiss: () -> Void
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                summaryCard
                if timeline.isCurrent {
                    inProgressCard
                } else {
                    cycleLengthCard
                    periodLengthCard
                }
                momentsCard
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingL)
            .padding(.bottom, AppLayout.spacingXXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { JourneyAnimatedBackground(animated: false) }
        .navigationTitle("Cycle details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary (date range + bar)

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summaryRange)
                .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            CycleHistoryBar(timeline: timeline)
        }
        .padding(22)
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
            Text("Cycle in progress")
                .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text)

            Text("Length figures appear once this cycle closes. Until then, the numbers would still be a projection.")
                .font(.raleway("Regular", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Cycle length

    @ViewBuilder
    private var cycleLengthCard: some View {
        let badge = CycleNormality.classifyCycleLength(days: timeline.length)
        statCard(
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

    // MARK: - Period length

    @ViewBuilder
    private var periodLengthCard: some View {
        let badge = CycleNormality.classifyPeriodLength(days: timeline.bleedingDays)
        statCard(
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
        title: String,
        value: String,
        badge: CycleStatusBadge,
        description: String,
        onInfoTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTypography.cardTitleTertiary)
                    .tracking(AppTypography.cardTitleTertiaryTracking)
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer(minLength: 8)

                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Learn more about \(title.lowercased())")
            }

            HStack(alignment: .center, spacing: 12) {
                Text(value)
                    .font(.raleway("Bold", size: 28, relativeTo: .title))
                    .tracking(-0.5)
                    .foregroundStyle(DesignColors.text)

                Spacer(minLength: 8)

                CycleStatusBadgeView(badge: badge)
            }

            Rectangle()
                .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                .frame(height: 0.5)

            Text(description)
                .font(.raleway("Regular", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Key moments

    @ViewBuilder
    private var momentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Key moments")
                .font(AppTypography.cardTitleTertiary)
                .tracking(AppTypography.cardTitleTertiaryTracking)
                .foregroundStyle(DesignColors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                momentRow(
                    tint: DesignColors.text,
                    assetIcon: "icon-period-start",
                    text: periodMomentText
                )

                Rectangle()
                    .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                    .frame(height: 0.5)

                momentRow(
                    tint: DesignColors.text,
                    assetIcon: "icon-fertile",
                    iconSize: 32,
                    text: fertileMomentText
                )

                Rectangle()
                    .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                    .frame(height: 0.5)

                momentRow(
                    tint: DesignColors.text,
                    assetIcon: "icon-ovulation",
                    text: ovulationMomentText
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    @ViewBuilder
    private func momentRow(
        tint: Color,
        icon: String? = nil,
        assetIcon: String? = nil,
        iconSize: CGFloat = 26,
        text: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let assetIcon {
                    Image(assetIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize * 0.77, weight: .semibold))
                }
            }
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)

            Text(text)
                .font(.raleway("Medium", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            return "Your period started on \(start)."
        }
        if timeline.bleedingDays <= 1 {
            return "Your period started on \(start)."
        }
        return "Your period ran from \(start) to \(end)."
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
            return "Your fertile window is expected between \(start) and \(end)."
        }
        return "Your fertile window likely ran from \(start) to \(end)."
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
            return "Ovulation is expected around \(label)."
        }
        return "Ovulation was likely on \(label)."
    }
}

