import SwiftUI

// MARK: - Phase Badge
//
// Compact phase capsule that lives in the card header and the detail
// sheet hero. Extracted so the color + pill chrome rule changes in
// exactly one place if the design language shifts.

struct BodySignalsPhaseBadge: View {
    let phase: CyclePhase

    var body: some View {
        HStack(spacing: 6) {
            // Same glossy ink as the per-day dots on the Cycle History
            // bar — keeps the menstrual / fertile / ovulatory vocabulary
            // consistent across the stats screen instead of using a
            // flat circle here and a glossy circle there.
            PhaseGlossyDot(tint: phase.orbitColor)
            Text(phase.displayName.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .accessibilityLabel("\(phase.displayName) phase")
    }
}
