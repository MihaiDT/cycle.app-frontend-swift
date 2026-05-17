import ComposableArchitecture
import SwiftUI

// MARK: - Me View
//
// Sticky collapsing-header shell that mirrors the Home (Today)
// screen's scroll-driven hero pattern exactly:
//
//   • Outer `GeometryReader` reads `safeAreaInsets.top`
//     synchronously so the header sits below the status bar on the
//     first paint (no async `onAppear` jump).
//   • `VStack(spacing: 0)` places `StoryHeroCard` directly above
//     the `ScrollView`. The `.ignoresSafeArea(edges: .top)` is
//     applied to the VStack INSIDE the GeometryReader (not on the
//     GR itself) so `rootGeo.safeAreaInsets.top` still reports the
//     real status-bar inset.
//   • Scroll offset is tracked the same way Today does: on iOS 18+
//     via `trackingScrollOffset` (which wraps
//     `onScrollGeometryChange`), with a 1pt `GeometryReader` +
//     `PreferenceKey` providing the iOS 17 fallback.
//   • `collapseCompensation = min(scrollOffset, threshold)` is a
//     spacer at the top of the scroll content that keeps the first
//     real item pinned to the hero's bottom while the header
//     collapses (the hero shrinks → ScrollView grows; the spacer
//     absorbs the delta so content doesn't visually jump).
//   • `.scrollTargetBehavior(CollapseSnapBehavior(threshold:))`
//     snaps the resting scroll position to either fully expanded
//     (0) or fully collapsed (threshold) — never a half-state.

public struct MeView: View {
    @Bindable var store: StoreOf<MeFeature>

    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollY: CGFloat?
    @State private var safeAreaTop: CGFloat = 0

    /// Expanded hero height (excludes safe area top).
    private let expandedHeaderHeight: CGFloat = 242
    /// Collapsed hero height (excludes safe area top) — 36pt
    /// avatar/chip row + 4pt top + 8pt bottom breathing room so
    /// the icons don't read as flush against the body content
    /// below. At full collapse the card surface is fully faded.
    private let collapsedHeaderHeight: CGFloat = 48
    /// Scroll distance over which collapse 0 → 1 completes. Equals
    /// the natural shrink (expanded − collapsed) so the compensation
    /// spacer absorbs exactly the collapse motion 1:1.
    private let collapseThreshold: CGFloat = 194

    public init(store: StoreOf<MeFeature>) {
        self.store = store
    }

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseThreshold, 0), 1)
    }

    /// Pins the first scroll item to the hero's bottom during collapse.
    /// Matches scrollOffset 1:1 until the threshold, then caps so
    /// normal scrolling resumes once the hero is fully collapsed.
    private var collapseCompensation: CGFloat {
        min(scrollOffset, collapseThreshold)
    }

    public var body: some View {
        GeometryReader { rootGeo in
            let liveSafeAreaTop = max(rootGeo.safeAreaInsets.top, safeAreaTop)

            VStack(spacing: 0) {
                StoryHeroCard(
                    story: store.story,
                    onTap: { store.send(.storyTapped) },
                    onAvatarTap: { store.send(.avatarTapped) },
                    topSafeArea: liveSafeAreaTop,
                    collapseProgress: collapseProgress
                )
                .zIndex(1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: MeScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 1)

                        // Pin first item to hero bottom during collapse.
                        // Wrapped in a transaction so this height change
                        // doesn't feed back into the scroll offset.
                        Color.clear
                            .frame(height: collapseCompensation)
                            .transaction { $0.animation = nil }

                        // Fill the viewport so the bottom of the screen
                        // never shows an empty ivory strip when the
                        // hero is fully collapsed and the body sheet's
                        // natural content would otherwise be shorter
                        // than the remaining scroll area.
                        MeBodySheet(
                            store: store,
                            minHeight: max(0, rootGeo.size.height - collapsedHeaderHeight - liveSafeAreaTop)
                        )
                    }
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(CollapseSnapBehavior(threshold: collapseThreshold))
                .trackingScrollOffset($scrollOffset)
                .onPreferenceChange(MeScrollOffsetKey.self) { value in
                    // iOS 17 fallback only.
                    if #unavailable(iOS 18.0) {
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            if initialScrollY == nil { initialScrollY = value }
                            scrollOffset = max(0, (initialScrollY ?? 0) - value)
                        }
                    }
                }
            }
            .background(
                ZStack {
                    DesignColors.background

                    AppleHealthBackground()
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.35),
                                    .init(color: .clear, location: 0.6),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
            )
            .ignoresSafeArea(edges: .top)
            .onAppear {
                safeAreaTop = rootGeo.safeAreaInsets.top
            }
            .onChange(of: rootGeo.safeAreaInsets.top) { _, new in
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    safeAreaTop = new
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}



private struct MeScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        MeView(
            store: .init(initialState: MeFeature.State()) {
                MeFeature()
            }
        )
    }
}
