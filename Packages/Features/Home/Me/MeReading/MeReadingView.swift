import ComposableArchitecture
import SwiftUI

// MARK: - Me Reading View
//
// One chapter per screen. Mirrors BondReadingView's layout so the
// two reading flows feel like siblings, but the top nav is a
// horizontal *chapter carousel* instead of progress dashes — the
// active chapter label is centered, neighbours fade off both edges,
// and the strip glides under a soft mask when the chapter changes.
// Each chapter label is tappable, in case the user wants to skip
// ahead without paging through with the chevron.
//
// Layout (top → bottom):
//   • Top bar: chapter carousel (left/center) + glass close X (right).
//   • Eyebrow pill (warm accent).
//   • Title — large editorial bold.
//   • Body — scroll-internal in case copy overflows on small screens.
//   • Bottom-right: large filled chevron-right next button; on the
//     last chapter it dismisses the flow.

public struct MeReadingView: View {
    @Bindable var store: StoreOf<MeReadingFeature>

    public init(store: StoreOf<MeReadingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)

                ZStack {
                    if let chapter = store.currentChapter {
                        chapterContent(for: chapter)
                            .id(store.currentIndex)
                            // Crossfade with a soft blur — same
                            // family as MeHeaderView's rotating
                            // greeting. Horizontal slides let the
                            // two texts overlap as they pass each
                            // other; blurReplace swaps them in
                            // place. `.blurReplace` is on the
                            // `Transition` protocol (iOS 17+), so
                            // it is applied inline rather than
                            // through an `AnyTransition` helper.
                            .transition(.blurReplace.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Clip horizontally so a `.push(from:)` transition
                // stays in its lane instead of bleeding past the
                // screen edge during the slide.
                .clipped()
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
            ChapterCarousel(
                chapters: store.chapters,
                currentIndex: store.currentIndex,
                onSelect: { idx in
                    UISelectionFeedbackGenerator().selectionChanged()
                    store.send(.chapterSelected(idx))
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            glassCloseButton
                .padding(.trailing, AppLayout.horizontalPadding)
        }
    }

    /// Liquid-glass close button — same nativeGlass interactive
    /// disc as BondReadingView so the two reading flows read as
    /// siblings.
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

    // MARK: - Chapter content

    private func chapterContent(for chapter: MeChapter) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            eyebrowPill(text: chapter.eyebrow)

            Text(chapter.title)
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.vertical, showsIndicators: false) {
                Text(chapter.body)
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
                store.isAtLast ? "Finish reading" : "Next chapter"
            )
        }
    }

}

// MARK: - Chapter Carousel
//
// Horizontal strip of chapter labels. The active label is centered
// and rendered in editorial bold; neighbours scale down and fade
// off both edges under a soft horizontal mask. Tapping a label
// jumps directly to that chapter. The strip uses ScrollViewReader
// so the active chapter slides to center under a spring animation
// whenever currentIndex changes — that's the "carousel" feel
// reused from the rotating MeHeaderView greeting.

private struct ChapterCarousel: View {
    let chapters: [MeChapter]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    @State private var scrollID: Int?

    private let activeFontSize: CGFloat = 18
    private let inactiveFontSize: CGFloat = 14
    private let spacing: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                        let isActive = idx == currentIndex
                        Button {
                            onSelect(idx)
                        } label: {
                            Text(chapter.label)
                                .font(
                                    .raleway(
                                        isActive ? "Bold" : "Medium",
                                        size: isActive ? activeFontSize : inactiveFontSize,
                                        relativeTo: .headline
                                    )
                                )
                                .tracking(isActive ? -0.2 : 0.1)
                                .foregroundStyle(
                                    isActive
                                        ? DesignColors.textPrincipal
                                        : DesignColors.textPrincipal.opacity(0.32)
                                )
                                .scaleEffect(isActive ? 1.0 : 0.94)
                                .animation(
                                    .spring(response: 0.45, dampingFraction: 0.86),
                                    value: currentIndex
                                )
                        }
                        .buttonStyle(.plain)
                        .id(idx)
                        .accessibilityLabel(chapter.label)
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
                // Anchor the active label near the left edge so
                // the upcoming chapter peeks generously on the
                // right. Leading inset matches the body content's
                // horizontal padding so the active label aligns
                // with the title beneath it; the trailing inset
                // is one viewport wide so the *last* chapter can
                // still snap to the leading anchor when scrolled
                // all the way through.
                .padding(.leading, AppLayout.horizontalPadding)
                .padding(.trailing, geo.size.width)
                .frame(height: geo.size.height)
            }
            // Swipe to browse all chapters; releases snap the
            // closest label to the leading anchor via
            // `viewAligned` so the active chapter is always
            // whichever label sits at the left. Externally-driven
            // changes (chevron-next / chevron-back) are mirrored
            // back here so the strip glides under the same spring.
            .scrollPosition(id: $scrollID, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.78),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                scrollID = currentIndex
            }
            .onChange(of: scrollID) { _, new in
                // User dragged the strip → reflect the new center
                // chapter back into the reducer. Skip the no-op
                // case where the change came from `currentIndex`
                // updating below.
                if let new, new != currentIndex {
                    onSelect(new)
                }
            }
            .onChange(of: currentIndex) { _, new in
                guard scrollID != new else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    scrollID = new
                }
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    MeReadingView(
        store: .init(initialState: MeReadingFeature.State()) {
            MeReadingFeature()
        }
    )
}
