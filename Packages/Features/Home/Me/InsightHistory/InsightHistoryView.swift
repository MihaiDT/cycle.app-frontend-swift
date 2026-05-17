import ComposableArchitecture
import SwiftUI

// MARK: - Insight History View
//
// Pinterest-style masonry of every insight the user has hearted on
// the Me tab. Each tile reuses the DailyInsightCard surface DNA
// (cycle-phase corner blobs + peach liquid + frosted overlay) at a
// smaller scale so the saved screen reads as a quiet collection of
// the same family of cards rather than a separate visual world.
//
// Layout: two columns, items distributed alternately so the column
// with less accumulated height takes the next tile. With variable
// text lengths this produces the staggered Pinterest feel without
// needing a custom Layout.

public struct InsightHistoryView: View {
    @Bindable var store: StoreOf<InsightHistoryFeature>

    public init(store: StoreOf<InsightHistoryFeature>) {
        self.store = store
    }

    public var body: some View {
        // Same NavigationStack-on-AppleHealthBackground shell as
        // BodyPatternsView / CycleInsightsView. The nav bar is
        // hidden via `.toolbarBackground(.hidden, ...)` so the
        // peach gradient bleeds all the way up, and the back
        // chevron + title are rendered as native toolbar items
        // for pixel-perfect parity with those screens.
        NavigationStack {
            ZStack {
                AppleHealthBackground()
                    .ignoresSafeArea()

                if store.insights.isEmpty {
                    emptyState
                        .padding(.horizontal, AppLayout.screenHorizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        masonryGrid
                            .padding(.horizontal, 10)
                            .padding(.top, AppLayout.spacingL)
                            .padding(.bottom, AppLayout.spacingXXL)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Saved insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.backTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    Text("Saved insights")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                }
            }
            // Native right-to-left push instead of a bottom-up
            // fullScreenCover. The InsightShareScreen lives inside
            // this NavigationStack, so popping (via back chevron
            // or swipe-back) writes nil to `selectedInsight`
            // automatically.
            .navigationDestination(item: $store.selectedInsight) { insight in
                InsightShareScreen(
                    insight: insight,
                    onDismiss: { store.selectedInsight = nil }
                )
            }
        }
        .tint(DesignColors.text)
    }

    // MARK: - Masonry grid
    //
    // Splits the insights into two columns by alternating assignment
    // (index % 2). With variable text lengths the natural heights
    // differ, so the columns stagger automatically — no custom
    // layout pass needed. Spacing between tiles tuned to feel as
    // airy as the primary Daily Insight card on the Me tab without
    // wasting too much vertical real-estate.

    private var masonryGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                ForEach(Array(leftColumn.enumerated()), id: \.element.id) { _, insight in
                    SavedInsightTile(
                        insight: insight,
                        onTap: { store.send(.tileTapped(insight.id)) },
                        onUnlike: { store.send(.unlikeTapped(insight.id)) }
                    )
                    // Shrink + fade on removal; the spring on
                    // the outer container then settles the
                    // surviving tiles into their new slots.
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.6).combined(with: .opacity)
                        )
                    )
                }
            }

            VStack(spacing: 14) {
                ForEach(Array(rightColumn.enumerated()), id: \.element.id) { _, insight in
                    SavedInsightTile(
                        insight: insight,
                        onTap: { store.send(.tileTapped(insight.id)) },
                        onUnlike: { store.send(.unlikeTapped(insight.id)) }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.6).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        // Spring layout reflow when a tile is unliked — gives
        // the surviving cards a soft settle instead of a hard
        // jump as items shift columns.
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: store.insights)
        // Per-tile `compositingGroup` is enough — a grid-level
        // `drawingGroup` was tried here but its Metal-backed
        // bitmap got invalidated on pop-back from the share
        // screen and the re-rasterisation showed up as lag when
        // re-entering this view. Without it, the per-tile
        // compositingGroups still collapse each tile's blur +
        // material + liquid stack into a single layer, so
        // scrolling stays cheap.
    }

    private var leftColumn: [DailyInsightItem] {
        store.insights.enumerated().compactMap { idx, item in
            idx.isMultiple(of: 2) ? item : nil
        }
    }

    private var rightColumn: [DailyInsightItem] {
        store.insights.enumerated().compactMap { idx, item in
            idx.isMultiple(of: 2) ? nil : item
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                VennCirclesWatermark(
                    strokeColor: DesignColors.textSecondary,
                    lineWidth: 1.6,
                    opacity: 0.18,
                    circleSize: 180,
                    overlap: 74
                )

                Image(systemName: "heart")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(DesignColors.textPrincipal.opacity(0.55))
            }
            .frame(height: 180)

            VStack(spacing: 8) {
                Text("Nothing saved yet")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.textPrincipal)

                Text("Tap the heart on a daily insight and it'll land here, ready to revisit.")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Saved Insight Tile
//
// Compact sibling of `DailyInsightCard`. Same surface treatment
// (phase-coloured corner blobs + peach liquid + frosted material)
// but smaller text, tighter paddings, and a single saved-state
// heart in the top-trailing corner — no large arrow chip and no
// big bottom-left heart, because in the saved view the whole point
// is that every tile is already saved. Tapping the heart unlikes.

private enum SavedInsightTileMetrics {
    static let cornerRadius: CGFloat = 20
    static let contentHorizontal: CGFloat = 16
    static let contentVertical: CGFloat = 20
    static let heartTop: CGFloat = 10
    static let heartTrailing: CGFloat = 10
}

private struct SavedInsightTile: View {
    let insight: DailyInsightItem
    let onTap: () -> Void
    let onUnlike: () -> Void

    /// Increments on every tap so the heart's keyframe burst
    /// re-runs from the start each time.
    @State private var heartTrigger: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                phasePill

                Text(insight.text)
                    .font(.raleway("Medium", size: 15, relativeTo: .footnote))
                    .tracking(-0.2)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SavedInsightTileMetrics.contentHorizontal)
            .padding(.vertical, SavedInsightTileMetrics.contentVertical)
            // Reserve space on the right so the trailing heart
            // chip never overlaps the text on narrow tiles.
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            heartButton
                .padding(.top, SavedInsightTileMetrics.heartTop)
                .padding(.trailing, SavedInsightTileMetrics.heartTrailing)
        }
        .background(tileSurface)
        // Outer clip — the surface's own clipShape doesn't always
        // contain the offset InsightLiquid render when the tile
        // is short, so add a second clip on the tile container
        // itself. Without this, the liquid asset visibly bled
        // below the bottom edge of short tiles and landed on top
        // of the next tile in the column, reading as overlap.
        .clipShape(RoundedRectangle(cornerRadius: SavedInsightTileMetrics.cornerRadius, style: .continuous))
        // Composite the layered blobs + material + liquid as a
        // single layer per frame. Avoids `drawingGroup()` (which
        // produced a sub-pixel ghost-outline on iOS 26 when
        // paired with the stroke overlay) but still collapses
        // per-effect compositing during the entrance transition.
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: SavedInsightTileMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        // Whole tile tappable → opens the full-screen share
        // preview. Heart button keeps its own hit area + handler
        // because it's a Button (priority over `onTapGesture`),
        // so liking from inside the tile doesn't accidentally
        // push the share screen at the same time.
        .contentShape(RoundedRectangle(cornerRadius: SavedInsightTileMetrics.cornerRadius, style: .continuous))
        .onTapGesture { onTap() }
    }

    // MARK: - Surface
    //
    // Scaled-down mirror of `DailyInsightCard.cardSurface` so the
    // tiles read as direct children of the main Daily Insight
    // card: ivory base + 4 phase-coloured corner blobs + the
    // peach InsightLiquid asset overflowing bottom-right + a
    // whisper of ultra-thin frost on top.
    //
    // Notably MISSING vs the main card: `drawingGroup(opaque:
    // false)` and the dual `.shadow(...)` stack. That combo
    // produced a visible ghost-outline rasterisation artifact on
    // iOS 26 where the rasterised drawing-group rendered at a
    // sub-pixel offset relative to the stroke overlay, making
    // each tile look like two cards stacked. The artifact didn't
    // appear on the bigger card, presumably because the blobs
    // were larger and softer. Drop the rasterisation + shadow and
    // the artifact disappears; scrolling is still cheap because
    // the tiles are small.

    private var tileSurface: some View {
        // Phase blobs + frost first — every child uses
        // `.frame(maxWidth: .infinity, maxHeight: .infinity, ...)`
        // wrappers or is a stretchy primitive (Color / Rectangle),
        // so the ZStack's natural size collapses to its host's
        // bounds in background mode. Critically, InsightLiquid
        // does NOT live in this ZStack — its fixed `.frame(110)`
        // would force the tile to be at least 110pt tall and
        // visually overflow the text content, which is what made
        // adjacent tiles look like they overlapped.
        ZStack {
            DesignColors.background

            // Top-leading — period rose
            Circle()
                .fill(DesignColors.calendarPeriodGlyph.opacity(0.16))
                .frame(width: 130, height: 130)
                .blur(radius: 18)
                .offset(x: -60, y: -60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Top-trailing — follicular oat
            Circle()
                .fill(DesignColors.calendarFollicularGlyph.opacity(0.30))
                .frame(width: 120, height: 120)
                .blur(radius: 16)
                .offset(x: 60, y: -55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Bottom-leading — fertile sand
            Circle()
                .fill(DesignColors.calendarFertileGlyph.opacity(0.20))
                .frame(width: 130, height: 130)
                .blur(radius: 18)
                .offset(x: -55, y: 55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Bottom-trailing — luteal mauve (paired with the liquid)
            Circle()
                .fill(DesignColors.calendarLutealGlyph.opacity(0.22))
                .frame(width: 120, height: 120)
                .blur(radius: 16)
                .offset(x: 55, y: 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Flat translucent frost in place of
            // `.ultraThinMaterial`. The real material costs a
            // full GPU recomposite every frame; on this list
            // that meant 8 materials × 60Hz, which dominated the
            // entry / pop animation cost. A plain white fill at
            // a tuned opacity reads visually almost identical
            // over the warm pastel surface and is free.
            Rectangle()
                .fill(Color.white.opacity(0.18))
        }
        .overlay(alignment: .bottomTrailing) {
            // InsightLiquid rendered as an overlay so its 110pt
            // intrinsic frame doesn't enlarge the parent. The
            // overlay tracks the surface's actual bounds and the
            // outer `.clipShape` (applied below) clips the liquid
            // back to the rounded rectangle, exactly like the
            // main DailyInsightCard does at full size.
            Image("InsightLiquid")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .opacity(0.60)
                .offset(x: 25, y: 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: SavedInsightTileMetrics.cornerRadius, style: .continuous))
    }

    private var phasePill: some View {
        Text(insight.phaseLabel)
            .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
            .tracking(-0.05)
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                // Flat translucent fill in place of
                // `.ultraThinMaterial` — same reason as the tile
                // surface: 16 materials on screen (8 tiles × 2)
                // are too expensive for the entry / pop frames.
                Capsule()
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(color: DesignColors.text.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    /// Compact filled-heart button — by definition every tile in
    /// this list is already saved, so the heart starts filled. A
    /// tap unfills with a quick scale punch and immediately calls
    /// `onUnlike` so the row disappears under the keyframe wind-
    /// down rather than waiting for the animation to finish.
    private var heartButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            heartTrigger &+= 1
            onUnlike()
        } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignColors.calendarPeriodGlyph)
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: heartTrigger
                ) { content, value in
                    content.scaleEffect(value)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.35, duration: 0.12, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove from saved")
    }
}

#Preview("With insights") {
    InsightHistoryView(
        store: .init(
            initialState: InsightHistoryFeature.State(
                insights: IdentifiedArrayOf(uniqueElements: DailyInsightItem.mockSaved),
                selectedInsight: nil
            )
        ) {
            InsightHistoryFeature()
        }
    )
}

#Preview("Empty") {
    InsightHistoryView(
        store: .init(initialState: InsightHistoryFeature.State()) {
            InsightHistoryFeature()
        }
    )
}
