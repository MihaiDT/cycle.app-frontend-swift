import SwiftUI

// MARK: - App Page Dots
//
// Reusable carousel page indicator. Pattern extracted from
// `YourDayFeature.dotsIndicator` (Home / Today surface — the
// proven implementation that doesn't flicker on swipe). Generic
// over the IDs of the carousel items so any horizontal pager can
// reuse it.
//
// Visual:
//   • Inactive dots — small warm-grey capsules at low opacity,
//     fixed width, present at all times.
//   • Active dot — same vertical capsule, animates wider into a
//     warm-tinted pill on `focusedID` change. Spring keeps the
//     transition feeling alive without overshooting.
//   • Tap-to-jump — when `onTap` is provided, each dot is its own
//     tappable target. Accessibility-friendly for users who can't
//     easily swipe through a long carousel.
//
// Usage:
// ```swift
// AppPageDots(
//     ids: patterns.map(\.id),
//     focusedID: focusedID,
//     onTap: { id in
//         withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
//             focusedID = id
//         }
//     }
// )
// ```

public struct AppPageDots<ID: Hashable>: View {
    public let ids: [ID]
    public let focusedID: ID?
    public let activeWidth: CGFloat
    public let inactiveWidth: CGFloat
    public let height: CGFloat
    public let spacing: CGFloat
    public let topPadding: CGFloat
    public let onTap: ((ID) -> Void)?

    public init(
        ids: [ID],
        focusedID: ID?,
        activeWidth: CGFloat = 20,
        inactiveWidth: CGFloat = 7,
        height: CGFloat = 7,
        spacing: CGFloat = 6,
        topPadding: CGFloat = 14,
        onTap: ((ID) -> Void)? = nil
    ) {
        self.ids = ids
        self.focusedID = focusedID
        self.activeWidth = activeWidth
        self.inactiveWidth = inactiveWidth
        self.height = height
        self.spacing = spacing
        self.topPadding = topPadding
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(ids, id: \.self) { id in
                let isActive = id == focusedID
                Capsule()
                    .fill(isActive ? activeFill : inactiveFill)
                    .frame(
                        width: isActive ? activeWidth : inactiveWidth,
                        height: height
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: focusedID)
                    .onTapGesture {
                        guard let onTap = onTap else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            onTap(id)
                        }
                    }
                    .accessibilityLabel(label(for: id))
                    .accessibilityAddTraits(isActive ? [.isSelected] : (onTap != nil ? [.isButton] : []))
            }
        }
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity)
    }

    /// Active fill is the warm terracotta token used on Today —
    /// keeps page indicators visually consistent across surfaces.
    /// Replaces the cocoa-gradient pill the previous version had,
    /// which read as a separate visual vocabulary from Home and
    /// was the dominant chrome on the dots row even when inactive.
    private var activeFill: AnyShapeStyle {
        AnyShapeStyle(DesignColors.accentWarm)
    }

    /// Inactive dots use the muted structure token at moderate
    /// opacity — visible enough to read as a row of indicators on
    /// their own (so the navigation never reads as "disappeared"
    /// during a swipe), tonally subordinate to the active pill.
    private var inactiveFill: AnyShapeStyle {
        AnyShapeStyle(DesignColors.structure.opacity(0.25))
    }

    private func label(for id: ID) -> String {
        let index = ids.firstIndex(of: id) ?? 0
        return "Page \(index + 1) of \(ids.count)"
    }
}
