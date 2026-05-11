import SwiftUI

// MARK: - Section Header
//
// Trailing chevron-only header. Section title is owned by
// `CycleInsightsView.sectionWrap("Your body")`; the phase badge
// that used to live here was removed (May 2026) — the canonical
// phase is already named on the today header at the top of the
// screen, repeating it on the BodySignals row read as duplicate
// chrome and made the section feel busier than its peers.

struct BodySignalsSectionHeader: View {
    var showsChevron: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 4)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
            }
        }
    }
}
