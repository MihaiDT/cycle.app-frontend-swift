import SwiftUI

// MARK: - Journey Destination Card (wide)
//
// Lead box on Home's Journey widget page. Points to the full Journey
// list — the recap-stories flow. Uses the same glass surface
// (`widgetCardStyle`) as the Rhythm hero so the two carousel pages
// feel like siblings from the same system.

public struct JourneyDestinationCard: View {
    public let subtitle: String
    public let isNew: Bool
    public let onTap: () -> Void

    public init(subtitle: String, isNew: Bool, onTap: @escaping () -> Void) {
        self.subtitle = subtitle
        self.isNew = isNew
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                meta
                    .padding(.bottom, 12)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your story")
                            .font(AppTypography.cardTitlePrimary)
                            .tracking(AppTypography.cardTitlePrimaryTracking)
                            .foregroundStyle(DesignColors.accentWarmText)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    journeyGlyph
                        .frame(width: 84, height: 84)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(18)
        .widgetCardStyle()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                .padding(.top, 12)
                .padding(.trailing, 12)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Journey. \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 8) {
            Text("JOURNEY")
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)

            if isNew {
                Text("NEW")
                    .font(.raleway("Black", size: 9, relativeTo: .caption2))
                    .tracking(0.5)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DesignColors.accentWarm))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var journeyGlyph: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Journey Destination Tile (half width)
//
// Secondary tile pair under the Journey card. Mirrors the `WellnessRitualTile`
// structure — text block on top-left, bottom-right glyph, glass surface —
// so the Journey page feels identical in rhythm to the Rhythm page.

public struct JourneyDestinationTile: View {
    public enum Kind: Sendable {
        case stats
        case body

        var badge: String {
            switch self {
            case .stats: return "CYCLE STATS"
            case .body:  return "BODY PATTERNS"
            }
        }

        var title: String {
            switch self {
            case .stats: return "Averages"
            case .body:  return "Symptoms"
            }
        }

        var subtitle: String {
            switch self {
            case .stats: return "Cycle length & trends"
            case .body:  return "Signals by phase"
            }
        }

        var icon: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .body:  return "heart.text.square.fill"
            }
        }
    }

    public let kind: Kind
    public let stat: String
    public let onTap: () -> Void

    public init(kind: Kind, stat: String, onTap: @escaping () -> Void) {
        self.kind = kind
        self.stat = stat
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                textBlock
                Spacer(minLength: 0)
                bottomRow
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .frame(minHeight: 190)
            .widgetCardStyle()
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.badge). \(kind.title). \(stat)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kind.badge)
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)

            Text(kind.title)
                .font(AppTypography.cardTitleSecondary)
                .tracking(AppTypography.cardTitleSecondaryTracking)
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)

            Text(kind.subtitle)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var bottomRow: some View {
        HStack(alignment: .center) {
            Text(stat)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.accentWarmText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: kind.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Preview

#Preview("Journey destinations") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        VStack(spacing: 12) {
            JourneyDestinationCard(
                subtitle: "Every cycle, a chapter of your story.",
                isNew: true,
                onTap: {}
            )
            HStack(alignment: .top, spacing: 12) {
                JourneyDestinationTile(kind: .stats, stat: "~28d", onTap: {})
                JourneyDestinationTile(kind: .body, stat: "Luteal", onTap: {})
            }
        }
        .padding(20)
    }
}
