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
    let onOpenDetail: () -> Void

    var body: some View {
        Button(action: onOpenDetail) {
            VStack(alignment: .leading, spacing: 14) {
                BodySignalsSectionHeader(phase: snapshot.phase, showsChevron: true)

                tiles
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens your body signals detail")
    }

    // MARK: - Tiles

    private var tiles: some View {
        HStack(spacing: 10) {
            BodySignalsMetricTile(
                metric: snapshot.wristTemperature,
                kind: .wristTemperature
            )
            BodySignalsMetricTile(
                metric: snapshot.hrv,
                kind: .hrv
            )
            BodySignalsMetricTile(
                metric: snapshot.restingHR,
                kind: .restingHR
            )
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
