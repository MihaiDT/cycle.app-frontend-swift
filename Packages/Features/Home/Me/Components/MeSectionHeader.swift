import SwiftUI

// MARK: - Me Section Header
//
// Standardised section title used inside the body sheet between
// cards. Mirrors the Home (Today) section style 1:1:
// `AppTypography.cardTitleSecondary` (Raleway Bold 22pt) with
// the matching tracking and a solid `DesignColors.text` fill —
// no gradient — so Today and Me read as one editorial system.
// Horizontal padding lines up with the cards
// (`AppLayout.screenHorizontal` = 14pt) so the labels and the
// card edges share the same gutter.

public struct MeSectionHeader: View {
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(AppTypography.cardTitleSecondary)
            .tracking(AppTypography.cardTitleSecondaryTracking)
            .foregroundStyle(DesignColors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, 12)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        MeSectionHeader("Your story")
        MeSectionHeader("Daily insight")
        MeSectionHeader("Your bonds")
    }
    .background(DesignColors.background)
}
