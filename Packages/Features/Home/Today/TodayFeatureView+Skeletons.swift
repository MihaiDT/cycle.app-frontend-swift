import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - TodayFeatureView › Empty-State + Skeleton views
//
// Placeholder surfaces used before cycle data loads (no cycle data
// hero, refresh indicator pill, skeleton hero). Lifted out so the
// main view can focus on live-data layout.

extension TodayView {
    // MARK: - No Cycle Data Hero

    @ViewBuilder
    var noCycleDataHero: some View {
        let creamTop = DesignColors.heroCreamTop
        let creamBottom = DesignColors.heroCreamBottom

        VStack(spacing: 0) {
            LinearGradient(
                colors: [creamTop, creamBottom],
                startPoint: .top, endPoint: .bottom
            )
            .overlay {
                VStack(spacing: 16) {
                    Spacer().frame(height: safeAreaTop + 20)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(DesignColors.accentWarm.opacity(0.6))

                    Text("No cycle logged")
                        .font(.custom("Raleway-Bold", size: 22, relativeTo: .title3))
                        .foregroundStyle(DesignColors.text)

                    Text("Start logging to discover your inner rhythm")
                        .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        store.send(.calendarTapped)
                    } label: {
                        Text("Open Calendar")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(DesignColors.accentWarm)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer()
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
            }
        }
        .frame(height: 320)
    }

    // MARK: - Dashboard Refresh Indicator (subtle pill for silent reloads)

    @ViewBuilder
    var dashboardRefreshIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(DesignColors.accentWarm)
            Text("Refreshing…")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.18), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Skeleton Hero

    @ViewBuilder
    var heroSkeleton: some View {
        let creamTop = DesignColors.heroCreamTop
        let creamBottom = DesignColors.heroCreamBottom
        let shimmer = Color.white.opacity(0.45)

        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            VStack(spacing: 0) {
                // Top row placeholders
                HStack {
                    Circle()
                        .fill(shimmer)
                        .frame(width: 36, height: 36)
                    Spacer()
                    Circle()
                        .fill(shimmer)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Week calendar placeholder
                HStack(spacing: 10) {
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(shimmer)
                                .frame(width: 16, height: 8)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(shimmer)
                                .frame(width: 34, height: 34)
                        }
                    }
                }
                .padding(.top, 14)

                Spacer(minLength: 12)

                // Phase label placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 90, height: 14)

                // Day number placeholder
                RoundedRectangle(cornerRadius: 10)
                    .fill(shimmer)
                    .frame(width: 120, height: 44)
                    .padding(.top, 8)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 5)
                    .fill(shimmer)
                    .frame(width: 140, height: 12)
                    .padding(.top, 8)

                Spacer(minLength: 16)

                // Button placeholders
                HStack(spacing: 10) {
                    Capsule()
                        .fill(shimmer)
                        .frame(width: 110, height: 36)
                    Capsule()
                        .fill(shimmer)
                        .frame(width: 90, height: 36)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(height: expandedHeroHeight + safeAreaTop)
        .background(
            LinearGradient(
                colors: [creamTop, creamBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(Rectangle())
        .modifier(ShimmerModifier())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your cycle")
        .accessibilityAddTraits(.updatesFrequently)
    }

}

