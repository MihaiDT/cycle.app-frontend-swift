import SwiftUI

/// Horizontally-scrollable capsule that hosts the category tabs.
/// Owns the matched-geometry namespace so the active highlight
/// slides between tabs instead of cross-fading. Auto-scrolls the
/// tapped tab to centre.
///
/// Layout intent (post-audit):
///   * The bar runs edge-to-edge — content carries its own
///     leading inset so the first tab can scroll past the
///     editorial column, just like `SymptomDaySelector`.
///   * A trailing fade mask softens the truncation of the
///     last tab into a "more here" cue rather than a hard
///     clip.
///   * The capsule container behind the row stays subtle —
///     it grounds the row without competing with the active
///     pill.
struct SymptomCategoryTabBar: View {
    @Binding var activeCategory: SymptomCategory
    /// Categories to render in the bar, in display order. The
    /// caller filters out hidden categories (e.g. removes
    /// `.smart` when the For-you toggle is off in Settings)
    /// so this view stays presentational.
    let categories: [SymptomCategory]

    @Namespace private var categoryNamespace

    private static let contentInset: CGFloat = 24

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(categories, id: \.rawValue) { category in
                        SymptomCategoryTab(
                            category: category,
                            isActive: activeCategory == category,
                            namespace: categoryNamespace,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                withAnimation(.appBalanced) {
                                    activeCategory = category
                                }
                                withAnimation {
                                    proxy.scrollTo(category.rawValue, anchor: .center)
                                }
                            }
                        )
                        .id(category.rawValue)
                    }
                }
                .padding(.horizontal, Self.contentInset)
                .padding(.vertical, 4)
            }
            // Trailing fade so the last visible tab doesn't
            // hard-clip — same recipe as `SymptomDaySelector`,
            // keeps the two row controls reading as the same
            // family.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .padding(.bottom, 24)
    }
}
