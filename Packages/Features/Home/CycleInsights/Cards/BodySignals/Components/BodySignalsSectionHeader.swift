import SwiftUI

// MARK: - Section Header
//
// Apple Health–style header — small outline icon + caps eyebrow on
// the left, optional phase badge on the right. Same 11pt eyebrow
// scale as Cycle Trend / Cycle History so the three Cycle Stats
// section markers read as siblings rather than one loud title in a
// row of quieter ones.

struct BodySignalsSectionHeader: View {
    let phase: CyclePhase?
    var showsChevron: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text("YOUR BODY")
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer(minLength: 4)

            if let phase {
                BodySignalsPhaseBadge(phase: phase)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
            }
        }
    }
}
