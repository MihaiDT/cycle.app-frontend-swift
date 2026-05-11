import SwiftUI

// MARK: - Data State
//
// The "happy path" teaser: phase badge + a horizontal row of three
// mini metric tiles (wrist temp / HRV / resting HR) + an "Explore"
// glass footer. Tapping anywhere on the card opens the detail screen
// — the whole content is wrapped in a single Button so the tile row
// reads as a preview, not a strip of independent buttons that each
// open the same destination.

struct BodySignalsDataState: View {
    let snapshot: BodySignalsSnapshot
    /// Per-metric tap routing. `nil` means the user tapped the
    /// header (or the card chrome) and wants the full detail
    /// surface from the top; a specific `Kind` means the user
    /// tapped that tile and wants the detail screen scrolled to
    /// the matching section.
    let onOpenDetail: (BodySignalMetric.Kind?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header + chevron removed (May 2026): the
            // "tap to see all metrics" destination duplicated
            // what the per-tile taps already do (each tile
            // routes to its own focused screen). The "Your
            // body" title is owned by `sectionWrap` in
            // CycleInsightsView; this card just renders the
            // tile row + its empty-state footer.
            tiles

            // Soft footer that appears only when all three
            // tiles render empty ("Soon"). Without it, three
            // greyed-out tiles read as broken; with it, the
            // user understands their Watch is collecting and
            // numbers will appear. Doesn't push to Settings —
            // honours the deliberate `.partial` state design
            // (see CLAUDE.md "BodySignals card · Permission flow").
            if allTilesEmpty {
                Text("Apple Watch is collecting. Numbers appear after a few nights.")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Tiles
    //
    // Each tile is its own button so taps route to the matching
    // section in `BodySignalsDetailView`. Wrapping the row in a
    // single Button (the previous behaviour) collapsed all three
    // tiles into the same destination, which read as broken once
    // the user noticed each metric had its own dedicated section
    // on the detail screen.

    private var tiles: some View {
        HStack(spacing: 10) {
            tileButton(
                metric: snapshot.wristTemperature,
                kind: .wristTemperature
            )
            tileButton(
                metric: snapshot.hrv,
                kind: .hrv
            )
            tileButton(
                metric: snapshot.restingHR,
                kind: .restingHR
            )
        }
    }

    @ViewBuilder
    private func tileButton(
        metric: BodySignalMetric?,
        kind: BodySignalMetric.Kind
    ) -> some View {
        Button(action: { onOpenDetail(kind) }) {
            BodySignalsMetricTile(metric: metric, kind: kind)
        }
        .buttonStyle(.plain)
    }

    /// True when no metric has any usable data — surfaces the
    /// "your Watch is collecting" footer. Mirrors `hasValue` in
    /// `BodySignalsMetricTile` so the empty signal stays consistent
    /// across both layers.
    private var allTilesEmpty: Bool {
        let metrics = [snapshot.wristTemperature, snapshot.hrv, snapshot.restingHR]
        return metrics.allSatisfy { metric in
            guard let metric, metric.latest != nil, metric.hasData else { return true }
            return false
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = ["Body signals"]
        if let phase = snapshot.phase {
            parts.append(phase.displayName + " phase")
        }
        for (metric, kind) in [
            (snapshot.wristTemperature, BodySignalMetric.Kind.wristTemperature),
            (snapshot.hrv, .hrv),
            (snapshot.restingHR, .restingHR)
        ] {
            guard let m = metric, let v = m.latest?.value else { continue }
            parts.append(
                kind.label + " " + formattedBodySignalValue(v, unit: m.unit, kind: kind)
            )
        }
        return parts.joined(separator: ". ")
    }
}
