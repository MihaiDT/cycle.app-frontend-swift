import SwiftUI

// MARK: - Home Widget Carousel
//
// Generic horizontal paged carousel for the Home screen. Each page holds
// a widget cluster (hero card + optional supporting tiles). The container
// snaps to full-page width and exposes the current page index via binding
// so the caller can drive an external dot indicator or a dynamic section
// header. iOS 17+ via `.scrollTargetBehavior(.paging)`.
//
// Usage:
//   HomeWidgetCarousel(currentIndex: $page, pageCount: 2) { index in
//       switch index {
//       case 0: RhythmPage()
//       case 1: JourneyPage()
//       default: EmptyView()
//       }
//   }

public struct HomeWidgetCarousel<PageContent: View>: View {
    @Binding public var currentIndex: Int
    public let pageCount: Int
    public let horizontalPadding: CGFloat
    public let pageSpacing: CGFloat
    public let peekAmount: CGFloat
    public let pageContent: (Int) -> PageContent

    public init(
        currentIndex: Binding<Int>,
        pageCount: Int,
        horizontalPadding: CGFloat = 18,
        pageSpacing: CGFloat = 12,
        peekAmount: CGFloat = 0,
        @ViewBuilder pageContent: @escaping (Int) -> PageContent
    ) {
        self._currentIndex = currentIndex
        self.pageCount = pageCount
        self.horizontalPadding = horizontalPadding
        self.pageSpacing = pageSpacing
        self.peekAmount = peekAmount
        self.pageContent = pageContent
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { index in
                    pageContent(index)
                        // Horizontal inset lives inside each page so the
                        // page itself still spans the full scroll view —
                        // no other page's edge can bleed into the viewport.
                        .padding(.horizontal, horizontalPadding)
                        // Vertical breathing room so widget shadows aren't
                        // clipped by the ScrollView's clip bounds.
                        .padding(.vertical, 12)
                        .containerRelativeFrame(.horizontal) { width, _ in
                            width
                        }
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding(
            get: { currentIndex },
            set: { currentIndex = $0 ?? 0 }
        ))
        // Disable the ScrollView's default vertical clipping so shadows
        // at the bottom of widget cards can bleed into the spacing above
        // the dot indicator instead of getting sliced off.
        .scrollClipDisabled(true)
        .accessibilityScrollAction { _ in
            // Let VoiceOver rotor drive paging — no extra wiring needed;
            // this satisfies the `.isAdjustable` expectation for carousels.
        }
    }
}

// MARK: - Page dots

/// Paginated dot indicator paired with `HomeWidgetCarousel`. Renders inline
/// (usually inside a `SectionHeader`'s trailing slot) so swiping the carousel
/// updates the dots without extra vertical space.
public struct HomeWidgetCarouselDots: View {
    public let pageCount: Int
    @Binding public var currentIndex: Int

    public init(pageCount: Int, currentIndex: Binding<Int>) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                let isActive = index == currentIndex
                Capsule()
                    .fill(
                        isActive
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.18)
                    )
                    .frame(width: isActive ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentIndex)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            currentIndex = index
                        }
                    }
                    .accessibilityLabel("Page \(index + 1) of \(pageCount)")
                    .accessibilityAddTraits(isActive ? [.isSelected] : [.isButton])
            }
        }
    }
}
