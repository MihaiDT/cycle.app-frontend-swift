import ComposableArchitecture
import SwiftUI

// MARK: - Me Body Sheet
//
// Ivory sheet that sits below the peach header and overlaps it by
// ~30pt. The content (section headers + cards) lives directly inside
// a non-scrolling stack — the parent surface owns the ScrollView so
// the header and the sheet can scroll together while a parallax
// counter-offset on the header gives the body a "rising over the
// header" feel.

private enum MeBodySheetMetrics {
    static let cornerRadius: CGFloat = 32
    static let topPadding: CGFloat = 22
    static let bottomPadding: CGFloat = 24
    static let interSectionSpacing: CGFloat = 18
    static let dotsStackSpacing: CGFloat = 18
    static let dotsBottomPadding: CGFloat = 6
}

public struct MeBodySheet: View {
    @Bindable var store: StoreOf<MeFeature>
    /// Minimum height the sheet should occupy. Lets MeView pass in
    /// the remaining screen real-estate so the sheet always bleeds
    /// down to the safe-area bottom even when the cards stop short.
    let minHeight: CGFloat

    public init(store: StoreOf<MeFeature>, minHeight: CGFloat = 0) {
        self.store = store
        self.minHeight = minHeight
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: MeBodySheetMetrics.interSectionSpacing) {
            MeSectionHeader("Daily insight")
                .padding(.top, MeBodySheetMetrics.topPadding)

            DailyInsightCard(
                insight: store.insight,
                isSaved: store.isInsightSaved,
                onSavedTap: { store.send(.insightSavedTapped) },
                onMenuTap: { store.send(.insightArrowTapped) }
            )

            MeSectionHeader("Your bonds")

            BondsCard(
                onAddTap: { store.send(.bondsAddTapped) },
                onArrowTap: { store.send(.bondsArrowTapped) }
            )
        }
        .padding(.bottom, MeBodySheetMetrics.bottomPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }
}

#Preview {
    ScrollView {
        MeBodySheet(
            store: .init(initialState: MeFeature.State()) { MeFeature() }
        )
    }
    .background(Color(hex: 0xEBCFC3))
}
