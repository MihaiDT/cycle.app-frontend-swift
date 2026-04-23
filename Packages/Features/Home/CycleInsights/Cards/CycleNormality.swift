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

// MARK: - Badge View

struct CycleStatusBadgeView: View {
    let badge: CycleStatusBadge

    var body: some View {
        if badge.tone == .normal {
            Text(badge.label.uppercased())
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(DesignColors.statusSuccess)
        } else {
            Text(badge.label.uppercased())
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(DesignColors.accentWarmText)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(DesignColors.accentWarm.opacity(0.16))
                }
                .overlay {
                    Capsule()
                        .stroke(DesignColors.accentWarm.opacity(0.34), lineWidth: 0.6)
                }
        }
    }
}

// MARK: - Row

struct CycleNormalityRow: View {
    let label: String
    let value: String
    let hasValue: Bool
    let badge: CycleStatusBadge?
    let onInfoTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppTypography.cardLabel)
                    .tracking(AppTypography.cardLabelTracking)
                    .foregroundStyle(DesignColors.text.opacity(0.72))
                    .lineLimit(1)

                Text(value)
                    .font(.raleway(
                        hasValue ? "Bold" : "SemiBold",
                        size: hasValue ? 22 : 17,
                        relativeTo: .title3
                    ))
                    .tracking(hasValue ? -0.3 : 0)
                    .foregroundStyle(
                        hasValue
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.45)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 12)

            if let badge {
                CycleStatusBadgeView(badge: badge)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn more about \(label.lowercased())")
        }
        .frame(minHeight: 56)
    }
}

// MARK: - Card

public struct CycleNormalityCard: View {
    public let previousCycleLength: Int?
    public let previousPeriodLength: Int?
    public let variationStdDev: Double?
    public let averageCycleLength: Double?
    public let cycleCount: Int
    public let onInfoTap: (CycleStatInfoKind) -> Void

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
            CycleNormalityRow(
                label: "Previous cycle length",
                value: previousCycleLength.map { "\($0) days" } ?? "No data",
                hasValue: previousCycleLength != nil,
                badge: previousCycleLength.map(CycleNormality.classifyCycleLength(days:)),
                onInfoTap: { onInfoTap(.cycleLength) }
            )

            divider

            CycleNormalityRow(
                label: "Previous period length",
                value: previousPeriodLength.map { "\($0) \($0 == 1 ? "day" : "days")" } ?? "No data",
                hasValue: previousPeriodLength != nil,
                badge: previousPeriodLength.map(CycleNormality.classifyPeriodLength(days:)),
                onInfoTap: { onInfoTap(.periodLength) }
            )

            divider

            variationRow

            if shouldShowCoachingFooter {
                divider
                    .padding(.top, 4)
                coachingFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    @ViewBuilder
    private var variationRow: some View {
        if let verdict = CycleNormality.classifyVariation(
            stdDev: variationStdDev,
            averageLength: averageCycleLength,
            cycleCount: cycleCount
        ) {
            CycleNormalityRow(
                label: "Cycle length variation",
                value: verdict.value,
                hasValue: true,
                badge: verdict.badge,
                onInfoTap: { onInfoTap(.cycleVariation) }
            )
        } else {
            CycleNormalityRow(
                label: "Cycle length variation",
                value: "No data",
                hasValue: false,
                badge: nil,
                onInfoTap: { onInfoTap(.cycleVariation) }
            )
        }
    }

    private var divider: some View {
        // 1pt fixed (not 0.5pt) — a sub-pixel line rounds to 1px on
        // @2x devices and 1-or-2px on @3x depending on where the row
        // above lands after layout, so adjacent dividers ended up
        // visibly different thicknesses. A full 1pt line rasterizes
        // identically on every row and every device scale.
        //
        // `.padding(.vertical, 10)` gives each row 10pt of breathing
        // room above the divider and 10pt below, so the three stat
        // lines read as distinct blocks instead of pressing against
        // their separators.
        Rectangle()
            .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private var shouldShowCoachingFooter: Bool {
        cycleCount < CycleNormality.minimumCyclesForVariation
    }

    @ViewBuilder
    private var coachingFooter: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DesignColors.text.opacity(0.55))
                .padding(.top, 2)

            Text("Keep tracking. Richer insights unlock once you've logged \(CycleNormality.minimumCyclesForVariation) full cycles.")
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.top, 14)
    }
}
