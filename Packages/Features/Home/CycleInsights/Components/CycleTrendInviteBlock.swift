import SwiftUI

// MARK: - Cycle Trend Invite Block
//
// Replaces the variation/range/position metric row when only one
// cycle has been logged. With a single bar on the chart there is
// no comparison to make: the variation cell would always print
// "On avg" (the cycle is, mathematically, the average), the
// position cell would print "1/1", and the range cell just
// rephrases the bar height. Instead, the row earns its real
// estate by telling the user exactly what's missing — the next
// cycle — so the comparison surface activates the moment it has
// data to compare.

struct CycleTrendInviteBlock: View, Equatable {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "plus.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Log your next cycle")
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)

                Text("Variation, range, and where each cycle lands in your rhythm unlock once you've logged a second cycle.")
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Log your next cycle. Variation, range, and position unlock once you've logged a second cycle.")
    }
}
