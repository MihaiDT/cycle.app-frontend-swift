import SwiftUI

// MARK: - Stat Ring Tile
//
// Hero stat tile used at the top of editorial stat screens (Cycle
// Stats overview row — Avg cycle, Avg period). Apple Health-style:
// the numeric value carries the screen, a quiet `MockRing` in the
// top-right corner gives the tile its accent identity, and the
// label sits underneath the value as a soft caption.
//
// Layout:
//
//   ┌───────────────────────┐
//   │                  ◜‾◝  │  MockRing (accent tint, top-right)
//   │                  ◟_◞  │
//   │                       │
//   │ 28 days               │  value+unit, baseline-aligned
//   │ Avg cycle             │  label, secondary tone
//   └───────────────────────┘
//
// `StatMetricTile` (the older compact tile) renders eyebrow-on-top
// content centered, which works inside nested compartments but
// feels generic at the top of an editorial screen. This tile keeps
// content left-aligned and lets the ring do the visual anchoring,
// so two stacked instances (Avg cycle + Avg period) still read as
// distinct cards via their ring tint instead of relying on color
// inside the value text itself.

public struct StatRingTile: View {
    public let label: String
    public let value: String?
    public let unit: String?
    public let ringTint: Color
    public let ringSize: CGFloat
    public let ringLineWidth: CGFloat
    public let ringTrim: CGFloat
    public let ringTrackTint: Color?
    public let ringTrackTrim: CGFloat?

    public init(
        label: String,
        value: String?,
        unit: String? = nil,
        ringTint: Color,
        ringSize: CGFloat = 28,
        ringLineWidth: CGFloat = 2.5,
        ringTrim: CGFloat = 0.78,
        ringTrackTint: Color? = nil,
        ringTrackTrim: CGFloat? = nil
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.ringTint = ringTint
        self.ringSize = ringSize
        self.ringLineWidth = ringLineWidth
        self.ringTrim = ringTrim
        self.ringTrackTint = ringTrackTint
        self.ringTrackTrim = ringTrackTrim
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            valueRow
            Text(label)
                .font(.raleway("SemiBold", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .bottomLeading)
        .overlay(alignment: .topTrailing) {
            MockRing(
                tint: ringTint,
                size: ringSize,
                lineWidth: ringLineWidth,
                trim: ringTrim,
                trackTint: ringTrackTint,
                trackTrim: ringTrackTrim
            )
            .padding(14)
        }
        .widgetCardStyle(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Value row

    @ViewBuilder
    private var valueRow: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppTypography.displayHeader)
                    .tracking(-0.5)
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("No data")
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = [label]
        if let value, !value.isEmpty {
            parts.append([value, unit].compactMap { $0 }.joined(separator: " "))
        } else {
            parts.append("no data")
        }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview("Stat Ring Tile – overview row") {
    HStack(spacing: 10) {
        StatRingTile(
            label: "Avg cycle",
            value: "28",
            unit: "days",
            ringTint: DesignColors.roseTaupe
        )
        StatRingTile(
            label: "Avg period",
            value: "5",
            unit: "days",
            ringTint: DesignColors.accentWarm
        )
    }
    .padding(14)
    .background(DesignColors.background)
}

#Preview("Stat Ring Tile – no data") {
    HStack(spacing: 10) {
        StatRingTile(
            label: "Avg cycle",
            value: nil,
            unit: "days",
            ringTint: DesignColors.roseTaupe
        )
        StatRingTile(
            label: "Avg period",
            value: nil,
            unit: "days",
            ringTint: DesignColors.accentWarm
        )
    }
    .padding(14)
    .background(DesignColors.background)
}
#endif
