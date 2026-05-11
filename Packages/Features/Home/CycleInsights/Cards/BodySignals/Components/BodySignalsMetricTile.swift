import SwiftUI

// MARK: - Metric Tile
//
// Compact mini-tile rendered inside the YOUR BODY card on Cycle Stats.
// Three of these line up in a row — wrist temperature / HRV / resting
// heart rate — each showing the latest reading at a glance.
//
// The tile is intentionally a *preview*, not a full chart cell. The
// detail sheet is where readings get a story (deltas, phase context,
// per-day curves). Here the tile just answers "what's the latest
// number, and is there one yet?" so the user can scan three metrics
// in a single eye sweep.

struct BodySignalsMetricTile: View {
    let metric: BodySignalMetric?
    let kind: BodySignalMetric.Kind

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: kind.outlineSymbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(DesignColors.text.opacity(hasValue ? 0.6 : 0.4))
                .frame(height: 22)

            valueBlock
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        // Each tile is now a full-fledged card — same
        // `widgetCardStyle` recipe as the rest of the screen,
        // so the three tiles read as siblings of the bigger
        // cards above instead of huddling inside an outer
        // wrapper. Replaces the inner subtle stroke + fill.
        .widgetCardStyle(cornerRadius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var valueBlock: some View {
        if let metric, let latest = metric.latest, metric.hasData {
            VStack(spacing: 2) {
                Text(numericString(for: latest.value, kind: kind))
                    .font(.raleway("Bold", size: 22, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(metric.unit)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                    .lineLimit(1)
            }
        } else {
            // Softer than "No Data" — wellness voice. Tells the
            // user "your Watch is collecting" without alarming
            // them that something's missing. Pairs with the
            // contextual footer in `BodySignalsDataState` when
            // all three tiles are empty (see `allEmpty` branch).
            Text("Soon")
                .font(.raleway("SemiBold", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    /// Numeric-only formatting — strips the trailing unit so the unit
    /// can render on its own line in a quieter weight. The shared
    /// `formattedBodySignalValue(...)` returns the joined "26 ms" /
    /// "76 bpm" / "36.5 °C" string used by other surfaces; the tile
    /// splits the same logic so the numeral keeps the spotlight.

    private func numericString(for value: Double, kind: BodySignalMetric.Kind) -> String {
        let joined = formattedBodySignalValue(value, unit: metric?.unit ?? "", kind: kind)
        if let unit = metric?.unit, !unit.isEmpty,
           let range = joined.range(of: unit) {
            return joined[..<range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
        }
        return joined
    }

    private var hasValue: Bool {
        metric?.latest != nil && metric?.hasData == true
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        guard let metric, let latest = metric.latest, metric.hasData else {
            return "\(kind.label), no data yet"
        }
        return "\(kind.label), \(formattedBodySignalValue(latest.value, unit: metric.unit, kind: kind))"
    }
}
