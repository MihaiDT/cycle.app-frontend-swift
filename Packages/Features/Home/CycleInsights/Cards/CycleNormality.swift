import SwiftUI

// MARK: - Cycle Normality
//
// "Where does this cycle sit on the clinical map?" — one card on the
// Cycle Stats sheet that takes the most recent completed cycle and the
// most recent period length, classifies each against ACOG windows, and
// surfaces a third diagnostic (cycle-to-cycle variation) once enough
// cycles have been logged. Every row is paired with an info affordance
// that opens a dedicated explainer sheet so the user can learn the
// "why" without being lectured on the dashboard itself.

public enum CycleStatusTone: Equatable, Sendable {
    /// Value sits inside the clinical normal window.
    case normal
    /// Value sits outside the window — not a diagnosis, an invitation
    /// to notice and (if persistent) check in with a provider.
    case needsAttention
}

public struct CycleStatusBadge: Equatable, Sendable {
    public let tone: CycleStatusTone
    public let label: String

    public init(tone: CycleStatusTone, label: String) {
        self.tone = tone
        self.label = label
    }
}

public enum CycleStatInfoKind: String, Equatable, Sendable, Identifiable, CaseIterable {
    case cycleLength
    case periodLength
    case cycleVariation

    public var id: String { rawValue }

    var eyebrow: String {
        switch self {
        case .cycleLength:    return "Rhythm reference"
        case .periodLength:   return "Bleed reference"
        case .cycleVariation: return "Variability reference"
        }
    }

    var title: String {
        switch self {
        case .cycleLength:    return "Cycle length"
        case .periodLength:   return "Period length"
        case .cycleVariation: return "Cycle length variation"
        }
    }

    var recapLabel: String {
        switch self {
        case .cycleLength:    return "Previous cycle length"
        case .periodLength:   return "Previous period length"
        case .cycleVariation: return "Current variation"
        }
    }

    var heroAsset: String {
        switch self {
        case .cycleLength:    return "stat-info-cycle-length-hero"
        case .periodLength:   return "stat-info-period-length-hero"
        case .cycleVariation: return "stat-info-cycle-variation-hero"
        }
    }
}

// MARK: - Classification
//
// Strict ACOG windows: adult cycle length 21–35 days, period length
// 2–7 days. Adolescent outliers (up to ~45d cycles, ~7–9d bleeds) are
// mentioned in the explainer copy but we do not soften the badge,
// because the card's job is to name what's outside the adult window,
// not to decide whether that's concerning.

public enum CycleNormality {
    public static let cycleLengthNormalMin = 21
    public static let cycleLengthNormalMax = 35
    public static let periodLengthNormalMin = 2
    public static let periodLengthNormalMax = 7
    public static let variationStableCeiling: Double = 4.0
    public static let minimumCyclesForVariation = 3

    public static func classifyCycleLength(days: Int) -> CycleStatusBadge {
        let ok = days >= cycleLengthNormalMin && days <= cycleLengthNormalMax
        return CycleStatusBadge(
            tone: ok ? .normal : .needsAttention,
            label: ok ? "Normal" : "Needs attention"
        )
    }

    public static func classifyPeriodLength(days: Int) -> CycleStatusBadge {
        let ok = days >= periodLengthNormalMin && days <= periodLengthNormalMax
        return CycleStatusBadge(
            tone: ok ? .normal : .needsAttention,
            label: ok ? "Normal" : "Needs attention"
        )
    }

    /// Variation verdict or `nil` when we don't yet have enough cycles
    /// to draw one. Expressed as the day interval cycles typically land
    /// in — `mean ± 1σ`, rounded to integers — rather than a raw `±σ`
    /// number. Reads like the RANGE pill on the avg card but with
    /// statistical meaning instead of raw min/max (an outlier cycle
    /// widens RANGE but barely touches this, which is what "variation"
    /// is supposed to communicate).
    public static func classifyVariation(
        stdDev: Double?,
        averageLength: Double?,
        cycleCount: Int
    ) -> (value: String, badge: CycleStatusBadge)? {
        guard cycleCount >= minimumCyclesForVariation,
              let sigma = stdDev, sigma >= 0,
              let mean = averageLength, mean > 0 else { return nil }
        let ok = sigma < variationStableCeiling
        let low = max(1, Int((mean - sigma).rounded()))
        let high = max(low, Int((mean + sigma).rounded()))
        let value: String
        if low == high {
            // σ collapsed to < half a day — everything rounds to the
            // mean. Fall back to a single-day label rather than an
            // interval like "30–30 days" that reads as a typo.
            value = "~\(low) days"
        } else {
            value = "\(low)–\(high) days"
        }
        return (
            value: value,
            badge: CycleStatusBadge(
                tone: ok ? .normal : .needsAttention,
                label: ok ? "Steady" : "Uneven"
            )
        )
    }
}

// MARK: - Card

public struct CycleNormalityCard: View, Equatable {
    public let previousCycleLength: Int?
    public let previousPeriodLength: Int?
    public let variationStdDev: Double?
    public let averageCycleLength: Double?
    public let cycleCount: Int
    public let onInfoTap: (CycleStatInfoKind) -> Void

    /// Equatable skips the closure: it always dispatches into a
    /// stable `historyPath` State binding owned by the parent view,
    /// so closure identity changing per parent body re-eval has no
    /// behavioral effect — only the data values matter for whether
    /// the card needs to re-render.
    /// `nonisolated` is required because `View` is implicitly
    /// `@MainActor`-isolated under Swift 6 strict concurrency, but
    /// SwiftUI calls `==` from its diffing pipeline outside the
    /// main actor context. The properties are all value types so
    /// the comparison is safe to run anywhere.
    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.previousCycleLength == rhs.previousCycleLength
            && lhs.previousPeriodLength == rhs.previousPeriodLength
            && lhs.variationStdDev == rhs.variationStdDev
            && lhs.averageCycleLength == rhs.averageCycleLength
            && lhs.cycleCount == rhs.cycleCount
    }

    public init(
        previousCycleLength: Int?,
        previousPeriodLength: Int?,
        variationStdDev: Double?,
        averageCycleLength: Double?,
        cycleCount: Int,
        onInfoTap: @escaping (CycleStatInfoKind) -> Void
    ) {
        self.previousCycleLength = previousCycleLength
        self.previousPeriodLength = previousPeriodLength
        self.variationStdDev = variationStdDev
        self.averageCycleLength = averageCycleLength
        self.cycleCount = cycleCount
        self.onInfoTap = onInfoTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            row(
                label: "Last cycle",
                value: previousCycleLength.map { "\($0) days" },
                tone: previousCycleLength
                    .map(CycleNormality.classifyCycleLength(days:))?.tone,
                onTap: { onInfoTap(.cycleLength) }
            )

            divider

            row(
                label: "Last period",
                value: previousPeriodLength.map {
                    "\($0) \($0 == 1 ? "day" : "days")"
                },
                tone: previousPeriodLength
                    .map(CycleNormality.classifyPeriodLength(days:))?.tone,
                onTap: { onInfoTap(.periodLength) }
            )

            divider

            variationRow

            if shouldShowCoachingFooter {
                divider
                coachingFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Row
    //
    // Apple Settings / Health-style row: label left, trailing value
    // (colored by status) + chevron. No nested tile chrome — the
    // parent card surface is enough.

    private func row(
        label: String,
        value: String?,
        tone: CycleStatusTone?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)

                Spacer(minLength: 8)

                Text(value ?? "No data")
                    .font(.raleway(value == nil ? "Medium" : "SemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(valueColor(tone: tone, hasValue: value != nil))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // `info.circle` (not `chevron.right`) — these rows
                // open an explainer ("what's typical", "what can shift
                // it") rather than a deeper data screen, so the
                // affordance should read "tap for context" rather
                // than "tap for more data".
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
            }
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(value ?? "no data")")
        .accessibilityHint("Opens an explainer for \(label.lowercased())")
    }

    private func valueColor(tone: CycleStatusTone?, hasValue: Bool) -> Color {
        guard hasValue else { return DesignColors.textSecondary.opacity(0.7) }
        switch tone {
        case .needsAttention: return DesignColors.accentHoneyText
        case .normal, .none:  return DesignColors.text
        }
    }

    @ViewBuilder
    private var variationRow: some View {
        if let verdict = CycleNormality.classifyVariation(
            stdDev: variationStdDev,
            averageLength: averageCycleLength,
            cycleCount: cycleCount
        ) {
            row(
                label: "Variation",
                value: verdict.value,
                tone: verdict.badge.tone,
                onTap: { onInfoTap(.cycleVariation) }
            )
        } else {
            row(
                label: "Variation",
                value: nil,
                tone: nil,
                onTap: { onInfoTap(.cycleVariation) }
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var shouldShowCoachingFooter: Bool {
        cycleCount < CycleNormality.minimumCyclesForVariation
    }

    @ViewBuilder
    private var coachingFooter: some View {
        let target = CycleNormality.minimumCyclesForVariation
        let current = max(0, min(cycleCount, target))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Richer insights ahead")
                    .font(.raleway("SemiBold", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.text)
                Spacer(minLength: 8)
                Text("\(current) / \(target) cycles")
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .tracking(0.4)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                    .contentTransition(.numericText())
            }

            milestoneBar(filled: current, total: target)

            Text("Variation, range, and cycle-to-cycle deltas unlock once you've logged \(target) full cycles.")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.top, 14)
    }

    /// Milestone strip — three small slots, filled in warm rose when
    /// the user has reached that step. Reads at a glance: "I'm 1/3
    /// of the way there", not "more lecturing about logging."
    private func milestoneBar(filled: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(
                        index < filled
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        DesignColors.accentWarm.opacity(0.85),
                                        DesignColors.accentWarm.opacity(0.55)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(DesignColors.text.opacity(0.10))
                    )
                    .frame(height: 5)
            }
        }
    }
}
