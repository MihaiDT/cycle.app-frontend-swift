import SwiftUI

// MARK: - Wellness Widget
//
// Home-tab hero summarizing the user's adjusted HBI as a warm Apple-style card.
// Consumes the W1 math pipeline (adjusted score + trend vs personal baseline).
// Tap-through is handled by the parent — this view is purely presentational.

public struct WellnessWidget: View {
    public let adjusted: Double
    public let trendVsBaseline: Double?
    public let phase: CyclePhase?
    public let cycleDay: Int?
    public let sourceLabel: String
    public let compact: Bool
    public let onDetailTap: (() -> Void)?

    public init(
        adjusted: Double,
        trendVsBaseline: Double?,
        phase: CyclePhase?,
        cycleDay: Int?,
        sourceLabel: String,
        compact: Bool = false,
        onDetailTap: (() -> Void)? = nil
    ) {
        self.adjusted = adjusted
        self.trendVsBaseline = trendVsBaseline
        self.phase = phase
        self.cycleDay = cycleDay
        self.sourceLabel = sourceLabel
        self.compact = compact
        self.onDetailTap = onDetailTap
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress: Double = 0
    @State private var hasAppeared: Bool = false

    // MARK: Derived

    private var percentValue: Int {
        max(0, min(100, Int(adjusted.rounded())))
    }

    private var fractionFilled: Double {
        max(0, min(1, adjusted / 100))
    }

    private var ringSize: CGFloat { compact ? 64 : 84 }
    private var ringStroke: CGFloat { 8 }
    private var bandSize: CGFloat { compact ? 26 : 32 }
    private var numberSize: CGFloat { compact ? 14 : 16 }
    private var unitSize: CGFloat { compact ? 11 : 12 }

    private var titleLabel: String { compact ? "Today" : "Rhythm" }

    private var phaseMetaText: String? {
        guard let phase, phase != .late else { return nil }
        if let cycleDay {
            return "\(phase.displayName) · Day \(cycleDay)"
        }
        return phase.displayName
    }

    /// Qualitative band derived from the adjusted score. Warm,
    /// non-judgmental vocabulary — "Tender" / "Gentle day" never "low".
    /// Gives the number meaning at a glance: user sees `60% · Balanced`
    /// and knows they're in a typical healthy zone without interpreting
    /// the raw percentage.
    private var band: WellnessBand {
        WellnessBand.from(score: adjusted)
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { onDetailTap?() }) {
                VStack(alignment: .leading, spacing: 0) {
                    if compact {
                        header
                            .padding(.bottom, 14)
                    } else if let meta = phaseMetaText {
                        // Phase + day as a tiny uppercase meta row at the
                        // top of the card. Moves it off the section header
                        // so the card is self-contained — no duplication.
                        Text(meta.uppercased())
                            .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                            .tracking(0.6)
                            .foregroundStyle(DesignColors.textSecondary)
                            .padding(.bottom, 12)
                    }

                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            bandLabelView
                            numberRow
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ring
                            .frame(width: ringSize, height: ringSize)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onDetailTap == nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(a11yLabel)
            .accessibilityHint(onDetailTap == nil ? "" : "Tap for wellness detail")
        }
        .padding(18)
        .widgetCardStyle()
        .overlay(alignment: .topTrailing) {
            // Diagonal "open detail" affordance in the top-right corner.
            // The ring is stroked (hollow), so its top-right bounding
            // corner is empty space — the chevron tucks into that gap
            // without colliding with the actual ring stroke.
            if onDetailTap != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            guard !reduceMotion else {
                ringProgress = fractionFilled
                return
            }
            withAnimation(.appBalanced.delay(0.15).speed(0.45)) {
                ringProgress = fractionFilled
            }
        }
        .onChange(of: fractionFilled) { _, newValue in
            guard hasAppeared else { return }
            withAnimation(reduceMotion ? nil : .appBalanced) {
                ringProgress = newValue
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleLabel)
                .font(.raleway("Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.text)
                .tracking(-0.1)

            Spacer(minLength: 8)

            if let meta = phaseMetaText {
                Text(meta)
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(0.2)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    // MARK: Ring

    @ViewBuilder
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.text.opacity(0.10), lineWidth: ringStroke)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            DesignColors.accentWarm,
                            DesignColors.accentSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Leaf sits at the heart of the ring — natural / grounding vibe,
            // keeps the ring from reading as empty after the percent moved
            // to the left column.
            Image(systemName: "leaf.fill")
                .font(.system(size: compact ? 20 : 26, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignColors.accentWarm,
                            DesignColors.accentSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityHidden(true)
    }

    // MARK: Number row

    @ViewBuilder
    private var bandLabelView: some View {
        Text(band.label)
            .font(.raleway("Bold", size: bandSize, relativeTo: .title2))
            .tracking(-0.6)
            .foregroundStyle(band.color)
            .lineLimit(1)
    }

    @ViewBuilder
    private var numberRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(percentValue)")
                .font(.raleway("SemiBold", size: numberSize, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .contentTransition(.numericText())
            Text("%")
                .font(.raleway("Medium", size: unitSize, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    // MARK: Accessibility label

    private var a11yLabel: String {
        let meta = phaseMetaText.map { ", \($0)" } ?? ""
        return "\(titleLabel) \(percentValue) percent, \(band.a11yLabel)\(meta)"
    }
}

// MARK: - Wellness band

/// Qualitative translation of the adjusted wellness score into a warm,
/// non-judgmental label. Keeps the number human: `60% · Balanced` reads
/// as "you're in a typical healthy zone" without making the user do the
/// math on whether a percentage is good or bad.
public enum WellnessBand: Sendable {
    case flowing    // 80+  — thriving
    case grounded   // 65–80
    case balanced   // 50–65 — normal, neutral
    case tender     // 35–50 — body asking for care
    case gentle     // <35   — soft day, not a "bad" day

    public static func from(score: Double) -> WellnessBand {
        let s = max(0, min(100, score))
        switch s {
        case 80...:      return .flowing
        case 65..<80:    return .grounded
        case 50..<65:    return .balanced
        case 35..<50:    return .tender
        default:         return .gentle
        }
    }

    public var label: String {
        switch self {
        case .flowing:  return "Flowing"
        case .grounded: return "Grounded"
        case .balanced: return "Balanced"
        case .tender:   return "Tender"
        case .gentle:   return "Gentle day"
        }
    }

    public var a11yLabel: String {
        switch self {
        case .flowing:  return "flowing"
        case .grounded: return "grounded"
        case .balanced: return "balanced"
        case .tender:   return "tender, your body is asking for care"
        case .gentle:   return "gentle day, be soft with yourself"
        }
    }

    /// Warm color that matches the band without punishing low scores.
    /// All stay in the app's warm palette — nothing turns red/amber.
    public var color: Color {
        switch self {
        case .flowing, .grounded, .balanced:
            return DesignColors.accentWarmText
        case .tender, .gentle:
            return DesignColors.textSecondary
        }
    }
}

// MARK: - Skeleton variant

/// Lightweight placeholder matching the widget shape. Used during first load
/// while the W1 pipeline is still resolving today's score.
public struct WellnessWidgetSkeleton: View {
    public init() {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    placeholder(width: 140, height: 30)
                    placeholder(width: 60, height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .stroke(DesignColors.text.opacity(0.10), lineWidth: 8)
                    .frame(width: 84, height: 84)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.text.opacity(0.04), lineWidth: 1)
                }
                .shadow(color: DesignColors.text.opacity(0.04), radius: 1, x: 0, y: 1)
                .shadow(color: DesignColors.text.opacity(0.06), radius: 12, x: 0, y: 8)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading wellness")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            guard !reduceMotion else { return }
            shimmer = true
        }
    }

    @ViewBuilder
    private func placeholder(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(DesignColors.text.opacity(shimmer ? 0.06 : 0.09))
            .frame(width: width, height: height)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: shimmer
            )
    }
}

// MARK: - Preview

#Preview("With trend") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        WellnessWidget(
            adjusted: 68,
            trendVsBaseline: 6,
            phase: .luteal,
            cycleDay: 22,
            sourceLabel: "Today's check-in · Health data"
        )
        .padding(18)
    }
}

#Preview("Building") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        WellnessWidget(
            adjusted: 62,
            trendVsBaseline: nil,
            phase: .follicular,
            cycleDay: 8,
            sourceLabel: "Today's check-in"
        )
        .padding(18)
    }
}

#Preview("Compact") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        WellnessWidget(
            adjusted: 73,
            trendVsBaseline: 11,
            phase: .luteal,
            cycleDay: 22,
            sourceLabel: "Today's check-in · Health data",
            compact: true
        )
        .padding(18)
    }
}

#Preview("Skeleton") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        WellnessWidgetSkeleton()
            .padding(18)
    }
}
