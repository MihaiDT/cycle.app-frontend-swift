import ComposableArchitecture
import SwiftUI

// MARK: - Bond Reading View
//
// One theme per screen. Layout (top → bottom):
//   • Top bar: back chevron (left), progress dashes (centre — one
//     dash per theme, the current one filled), close X (right).
//   • Eyebrow pill (theme subtitle, e.g. "Rhythm") in `accentWarm`.
//   • Title — large editorial bold.
//   • Body — scroll-internal in case copy overflows on small screens.
//   • Bottom-right: large filled chevron-right button advancing to
//     the next theme; on the last theme it dismisses the flow.
// The active section is keyed off `store.currentIndex`; transitions
// between themes are direction-aware (forward = slide-from-trailing,
// backward = slide-from-leading) using `store.lastNavigation`.

public struct BondReadingView: View {
    @Bindable var store: StoreOf<BondReadingFeature>

    public init(store: StoreOf<BondReadingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.top, 8)

                ZStack {
                    if let theme = store.currentTheme {
                        themeContent(for: theme)
                            .id(store.currentIndex)
                            // Crossfade with a soft blur — same
                            // family as MeReadingView and the
                            // rotating MeHeaderView greeting.
                            // Horizontal slides let the two texts
                            // visibly overlap as they pass each
                            // other; blurReplace swaps them in
                            // place. `.blurReplace` is on the
                            // `Transition` protocol (iOS 17+), so
                            // it is applied inline rather than
                            // through `themeTransition`.
                            .transition(.blurReplace.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.86),
                    value: store.currentIndex
                )

                bottomBar
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            progressDashes
                .frame(maxWidth: .infinity, alignment: .leading)

            glassCloseButton
        }
    }

    /// Liquid-glass close button — wraps the DesignSystem
    /// `nativeGlass(in:interactive:)` so on iOS 26+ it picks up
    /// Apple's `.glassEffect(.regular.interactive())` (the disc
    /// visibly deforms / "bubbles" while held), with the standard
    /// `.ultraThinMaterial` + rim + drop shadow fallback on iOS
    /// 17–25. Same 44pt footprint as `GlassBackButton` so back and
    /// close read as a pair.
    private var glassCloseButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            store.send(.closeTapped)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 44, height: 44)
                .nativeGlass(in: Circle(), interactive: true)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close reading")
        .accessibilityHint("Closes the reading flow")
    }

    private var progressDashes: some View {
        HStack(spacing: 5) {
            ForEach(0..<store.bond.themes.count, id: \.self) { idx in
                Capsule(style: .continuous)
                    .fill(
                        idx == store.currentIndex
                            ? DesignColors.textPrincipal.opacity(0.85)
                            : DesignColors.textPrincipal.opacity(0.16)
                    )
                    .frame(width: 22, height: 3)
                    .animation(.easeOut(duration: 0.22), value: store.currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Theme \(store.currentIndex + 1) of \(store.bond.themes.count)"
        )
    }

    // MARK: - Theme content

    private func themeContent(for theme: BondTheme) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            eyebrowPill(text: theme.subtitle)

            Text(theme.title)
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Body wrapped in a ScrollView so long copy stays
            // reachable on small devices — most themes fit on a
            // 6.1" without scrolling.
            ScrollView(.vertical, showsIndicators: false) {
                Text(theme.body)
                    .font(.raleway("Medium", size: 17, relativeTo: .body))
                    .tracking(0.05)
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 24)
    }

    private func eyebrowPill(text: String) -> some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .tracking(0.4)
                .foregroundStyle(DesignColors.background)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(DesignColors.accentWarm)
                )

            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Spacer()

            Button {
                store.send(.nextTapped)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignColors.background)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(DesignColors.textPrincipal)
                    )
                    .shadow(
                        color: DesignColors.textPrincipal.opacity(0.18),
                        radius: 10, x: 0, y: 4
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                store.isAtLast ? "Finish reading" : "Next theme"
            )
        }
    }

}

#Preview {
    BondReadingView(
        store: .init(
            initialState: BondReadingFeature.State(bond: Bond.mock(seed: 0))
        ) {
            BondReadingFeature()
        }
    )
}
