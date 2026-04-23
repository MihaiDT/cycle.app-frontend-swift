import ComposableArchitecture
import SwiftUI

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Collapse Snap Behavior

/// Snaps scroll to either fully expanded (0) or fully collapsed (threshold).
/// Prevents the hero from resting at intermediate collapse states.
struct CollapseSnapBehavior: ScrollTargetBehavior {
    let threshold: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.origin.y
        if y > 0 && y < threshold {
            // Snap at 35% — collapses easily, resists expanding back
            target.rect.origin.y = y < threshold * 0.35 ? 0 : threshold
        }
    }
}

// MARK: - Scroll Offset Tracking (iOS 18+ uses onScrollGeometryChange)

extension View {
    @ViewBuilder
    func trackingScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                let clamped = max(0, newValue)
                // Skip tiny changes to break feedback oscillation
                if abs(clamped - offset.wrappedValue) > 0.5 {
                    offset.wrappedValue = clamped
                }
            }
        } else {
            self
        }
    }
}

// MARK: - Daily Glow Presentations

/// Extracted to a ViewModifier to reduce type-check complexity in TodayView.body.
struct DailyGlowPresentations: ViewModifier {
    @Bindable var store: StoreOf<TodayFeature>

    func body(content: Content) -> some View {
        content
            // Daily Glow — challenge journey (full-screen)
            .fullScreenCover(
                item: $store.scope(
                    state: \.dailyChallengeState.journey,
                    action: \.dailyChallenge.journey
                )
            ) { journeyStore in
                ChallengeJourneyView(store: journeyStore)
            }
            // Daily Glow — level up overlay
            .sheet(
                item: $store.scope(
                    state: \.dailyChallengeState.levelUp,
                    action: \.dailyChallenge.levelUp
                )
            ) { levelUpStore in
                LevelUpOverlay(store: levelUpStore)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.ultraThinMaterial)
            }
            // Wellness detail sheet (W2)
            .sheet(
                item: $store.scope(
                    state: \.wellnessDetail,
                    action: \.wellnessDetail
                )
            ) { detailStore in
                WellnessDetailView(store: detailStore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppLayout.cornerRadiusL)
                    .presentationBackground(DesignColors.background)
            }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        let leading = max(0, min(phase - 0.15, 1))
        let center = max(0, min(phase, 1))
        let trailing = max(0, min(phase + 0.15, 1))

        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: leading),
                        .init(color: .white.opacity(0.25), location: center),
                        .init(color: .clear, location: trailing),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            }
            .onAppear {
                // withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    // phase = 1.15
                // }
            }
    }
}
