import SwiftUI

// MARK: - Story Hero Card
//
// Collapsing header sheet for the ME tab. Expanded shows: avatar +
// arrow chip top row, then a tagline, eyebrow + horizontal category
// slider. As `collapseProgress` ramps from 0 → 1 (driven by the
// ScrollView's scroll offset), the lower content fades + clips to
// zero height and the card shrinks down to a thin nav-bar style
// row with just the avatar (leading) and arrow chip (trailing).

private enum StoryHeroMetrics {
    /// Matches `AppLayout.cornerRadiusL` (24) used by the Home
    /// `CycleHeroView` so the two collapsing headers share the
    /// same bottom-corner curvature both expanded and collapsed.
    static let cornerRadius: CGFloat = 24
    static let collapsedCornerRadius: CGFloat = 24
    static let expandedContentHeight: CGFloat = 150
    static let contentPaddingHorizontal: CGFloat = 22
    static let expandedTopPadding: CGFloat = 8
    static let collapsedTopPadding: CGFloat = 4
    static let expandedBottomSpacing: CGFloat = 32
    static let collapsedBottomSpacing: CGFloat = 8
    static let contentPaddingBottom: CGFloat = 0
    static let expandedButtonSize: CGFloat = 52
    static let collapsedButtonSize: CGFloat = 36
    static let sliderSpacing: CGFloat = 22
    static let sectionSpacing: CGFloat = 8
}

public struct StoryHeroCard: View {
    public let story: MyStoryCard
    public let onTap: () -> Void
    public let onAvatarTap: () -> Void
    /// Extra top padding to inset content below the status bar.
    public let topSafeArea: CGFloat
    /// 0 = fully expanded (all content visible), 1 = fully
    /// collapsed (only the top bar with avatar + arrow remains).
    public let collapseProgress: CGFloat

    @State private var focusedCategoryID: UUID?

    public init(
        story: MyStoryCard,
        onTap: @escaping () -> Void,
        onAvatarTap: @escaping () -> Void = {},
        topSafeArea: CGFloat = 0,
        collapseProgress: CGFloat = 0
    ) {
        self.story = story
        self.onTap = onTap
        self.onAvatarTap = onAvatarTap
        self.topSafeArea = topSafeArea
        self.collapseProgress = collapseProgress
    }

    /// Linear interpolation 0 (expanded) → 1 (collapsed).
    private func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * collapseProgress
    }

    /// Avatar / arrow button size — shrinks toward a navbar-style
    /// compact size at full collapse so the pinned row reads like
    /// a clean iOS nav bar (≈44pt content + safe area) rather than
    /// an oversized strip.
    private var buttonSize: CGFloat {
        lerp(StoryHeroMetrics.expandedButtonSize, StoryHeroMetrics.collapsedButtonSize)
    }

    /// Bottom corner radius — matches the Home `CycleHeroView`
    /// (24pt) both expanded and collapsed so the two collapsing
    /// headers share the same silhouette across the app.
    private var bottomCornerRadius: CGFloat {
        lerp(StoryHeroMetrics.cornerRadius, StoryHeroMetrics.collapsedCornerRadius)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, StoryHeroMetrics.contentPaddingHorizontal)
                .padding(.top, lerp(StoryHeroMetrics.expandedTopPadding, StoryHeroMetrics.collapsedTopPadding) + topSafeArea)
                .padding(.bottom, lerp(StoryHeroMetrics.expandedBottomSpacing, StoryHeroMetrics.collapsedBottomSpacing))

            collapsibleContent
                .opacity(Double(pow(1 - collapseProgress, 2)))
                .blur(radius: collapseProgress * 14)
                .frame(
                    height: StoryHeroMetrics.expandedContentHeight * (1 - collapseProgress),
                    alignment: .top
                )
                .clipped()

            // Bottom breathing room when expanded, collapses to 0
            Spacer(minLength: 0)
                .frame(height: StoryHeroMetrics.contentPaddingBottom * (1 - collapseProgress))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            cardSurface
                .opacity(Double(pow(1 - collapseProgress, 1.5)))
        )
        .overlay(
            UnevenRoundedRectangle(
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        DesignColors.text.opacity(0.22),
                        DesignColors.accentWarm.opacity(0.38),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
        )
        // Shadows fade out as the card collapses — at the navbar
        // state the drop shadow would otherwise read as a visible
        // dark "margin" under the icons, breaking the flush look.
        .shadow(color: DesignColors.text.opacity(0.12 * (1 - collapseProgress)), radius: 28, x: 0, y: 14)
        .shadow(color: DesignColors.text.opacity(0.05 * (1 - collapseProgress)), radius: 4, x: 0, y: 2)
        .onAppear {
            if focusedCategoryID == nil {
                focusedCategoryID = story.categories.first?.id
            }
        }
    }

    // MARK: - Sections

    /// Avatar (leading) + arrow chip (trailing). Always visible, no
    /// fade — this is the collapsed-state "nav bar" the user sees
    /// once they scroll past the expanded content.
    private var topBar: some View {
        HStack(spacing: 0) {
            MeHeaderRoundButton(
                variant: .avatar,
                size: buttonSize,
                action: onAvatarTap
            )

            Spacer(minLength: 0)

            Button(action: onTap) {
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    DesignColors.calendarPeriodGlyph,
                                    DesignColors.calendarFollicularGlyph,
                                    DesignColors.calendarFertileGlyph,
                                    DesignColors.calendarLutealGlyph,
                                    DesignColors.calendarPeriodGlyph,
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 1.4, dash: [3, 4])
                        )
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: buttonSize * 0.346, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                }
                .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open story")
        }
    }

    /// Tagline + eyebrow + horizontal category slider. Fades out
    /// and clips to zero height as `collapseProgress` advances.
    private var collapsibleContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(story.tagline)
                .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, StoryHeroMetrics.contentPaddingHorizontal)

            VStack(alignment: .leading, spacing: StoryHeroMetrics.sectionSpacing) {
                Text(story.eyebrow.uppercased())
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.horizontal, StoryHeroMetrics.contentPaddingHorizontal)

                categorySlider
            }
        }
    }

    private var categorySlider: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .lastTextBaseline, spacing: StoryHeroMetrics.sliderSpacing) {
                ForEach(story.categories) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal, StoryHeroMetrics.contentPaddingHorizontal)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedCategoryID, anchor: .leading)
    }

    private func categoryButton(for category: StoryCategory) -> some View {
        let isFocused = category.id == focusedCategoryID

        return Button {
            guard !isFocused else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                focusedCategoryID = category.id
            }
        } label: {
            Text(category.label)
                .font(.raleway("Bold", size: 36, relativeTo: .largeTitle))
                .tracking(-0.8)
                .foregroundStyle(
                    isFocused
                        ? AnyShapeStyle(DesignColors.text)
                        : AnyShapeStyle(DesignColors.text.opacity(0.25))
                )
                .scaleEffect(isFocused ? 1.0 : 0.94, anchor: .bottomLeading)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .id(category.id)
        .accessibilityLabel(category.label)
        .accessibilityHint(isFocused ? "Selected" : "Tap to focus")
    }

    // MARK: - Surface

    /// Same surface as `DailyInsightCard` / `BondsCard`: ivory base
    /// + four subtle cycle-phase corner blooms + frosted material.
    /// Rasterised so scroll just translates a cached texture.
    private var cardSurface: some View {
        ZStack {
            DesignColors.background

            Circle()
                .fill(DesignColors.calendarPeriodGlyph.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -100, y: -100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Circle()
                .fill(DesignColors.calendarFollicularGlyph.opacity(0.30))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 100, y: -90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Circle()
                .fill(DesignColors.calendarFertileGlyph.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -90, y: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Circle()
                .fill(DesignColors.calendarLutealGlyph.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 90, y: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.22)
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                style: .continuous
            )
        )
        .drawingGroup(opaque: false)
    }
}

#Preview {
    VStack(spacing: 16) {
        StoryHeroCard(story: .mock, onTap: {}, topSafeArea: 0, collapseProgress: 0)
        StoryHeroCard(story: .mock, onTap: {}, topSafeArea: 0, collapseProgress: 0.5)
        StoryHeroCard(story: .mock, onTap: {}, topSafeArea: 0, collapseProgress: 1)
    }
    .padding(.vertical, 40)
    .background(DesignColors.background)
}
