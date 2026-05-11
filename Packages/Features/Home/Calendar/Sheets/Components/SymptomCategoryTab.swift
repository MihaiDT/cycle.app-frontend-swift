import SwiftUI

/// Single tab in the category bar. Active state morphs the
/// background via `matchedGeometryEffect("activeTab", …)` so
/// switching tabs slides the highlight instead of cross-fading.
///
/// Active vs inactive vocabulary is intentionally tonal, not
/// surface-vs-no-surface: both states render the icon + text
/// at the same size, but the active tab fills with a soft
/// warm glass pill and tints the icon + text in `accentWarm`
/// so the row reads as one coherent control rather than
/// "one tab is alive, the rest are dead". The lightbulb on
/// "For you" no longer comes through as a yellow SF Symbol
/// — it inherits the warm tint like every other category.
struct SymptomCategoryTab: View {
    let category: SymptomCategory
    let isActive: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.monochrome)

                Text(category.rawValue)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isActive
                    ? DesignColors.accentWarm
                    : DesignColors.textSecondary.opacity(0.55)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                // Always render the active background so SwiftUI
                // never has to lay out a zero-size shape during a
                // tab switch (the source of `clip: empty path`
                // runtime warnings). `isSource` keeps the matched
                // geometry contribution attached only to the
                // currently-active tab; the others fade through
                // opacity but never give up their layout slot.
                activeBackground
                    .matchedGeometryEffect(
                        id: "activeTab",
                        in: namespace,
                        isSource: isActive
                    )
                    .opacity(isActive ? 1 : 0)
                    .shadow(color: DesignColors.accentWarm.opacity(0.15), radius: 6, x: 0, y: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private var activeBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.78),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        DesignColors.accentWarm.opacity(0.30),
                        lineWidth: 0.8
                    )
            }
    }
}
