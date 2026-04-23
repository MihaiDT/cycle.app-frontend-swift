import ComposableArchitecture
import SwiftUI


// MARK: - Profile View

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppLayout.spacingL) {
                    profileHeader
                    glowSection
                    cycleOverviewCard
                    wellnessCard
                    settingsSection
                    aboutSection
                    privacyActionsSection
                    VerticalSpace(AppLayout.spacingXL)
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingM)
            }
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.loadGlowProfile) }
    }

    // MARK: - Profile Header

    var profileHeader: some View {
        VStack(spacing: AppLayout.spacingM) {
            // Avatar with gradient ring
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColors.accent.opacity(0.4),
                                DesignColors.accent.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 65
                        )
                    )
                    .frame(width: 130, height: 130)

                // Gradient border ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                DesignColors.accent,
                                DesignColors.accentSecondary,
                                DesignColors.accentWarm,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 100, height: 100)

                // Avatar circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignColors.accent.opacity(0.6),
                                DesignColors.accentSecondary.opacity(0.4),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 94, height: 94)
                    .overlay {
                        if let user = store.user {
                            Text(user.initials)
                                .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
                                .foregroundColor(DesignColors.text)
                        }
                    }
            }

            // Name & email
            VStack(spacing: 6) {
                if let fullName = store.user?.fullName {
                    Text(fullName)
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundColor(DesignColors.text)
                }

                if let email = store.user?.email {
                    Text(email)
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundColor(DesignColors.textSecondary)
                }

                if let memberSince = store.state.memberSinceFormatted {
                    Text("Member since \(memberSince)")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textPlaceholder)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, AppLayout.spacingL)
        .frame(maxWidth: .infinity)
        .background { glassCard(cornerRadius: AppLayout.cornerRadiusXL) }
    }

    // MARK: - Glow Section

    @ViewBuilder
    var glowSection: some View {
        if let profile = store.glowProfile, profile.totalCompleted > 0 {
            let level = GlowConstants.levelFor(xp: profile.totalXP)
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Daily Glow")
                        .font(.raleway("Bold", size: 18, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                }

                // Level + XP
                HStack(spacing: 16) {
                    // Level emoji big
                    Text(level.emoji)
                        .font(.system(size: 44))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(level.title)
                            .font(.raleway("Bold", size: 20, relativeTo: .title2))
                            .foregroundStyle(DesignColors.text)

                        Text("Level \(level.level) · \(profile.totalXP) XP")
                            .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Spacer()
                }

                // Progress bar
                XPProgressBar(currentXP: profile.totalXP, animated: false)

                // Stats row
                HStack(spacing: 0) {
                    glowStat(value: "\(profile.totalCompleted)", label: "Challenges")
                    Spacer()
                    glowStat(value: "\(profile.goldCount)", label: "🥇")
                    Spacer()
                    glowStat(value: "\(profile.silverCount)", label: "🥈")
                    Spacer()
                    glowStat(value: "\(profile.bronzeCount)", label: "🥉")
                    Spacer()
                    glowStat(value: "\(profile.currentConsistencyDays)d", label: "Streak")
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [DesignColors.structure.opacity(0.4), DesignColors.accentWarm.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
        }
    }

    func glowStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.raleway("Bold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text(label)
                .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    // MARK: - Cycle Overview Card

    @ViewBuilder
    var cycleOverviewCard: some View {
        if let status = store.menstrualStatus, status.hasCycleData {
            VStack(alignment: .leading, spacing: AppLayout.spacingM) {
                // Section header
                sectionHeader(title: "Cycle Overview", icon: "circle.circle")

                // Phase badge
                if let phase = store.state.cyclePhase {
                    HStack(spacing: 10) {
                        Image(systemName: phase.icon)
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.accentWarm)

                        Text("Day \(status.currentCycle.cycleDay) · \(phase.displayName) Phase")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                            .foregroundColor(DesignColors.text)

                        Spacer()
                    }
                    .padding(.horizontal, AppLayout.screenHorizontal)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusS)
                            .fill(DesignColors.accent.opacity(0.15))
                    }
                }

                // Stats grid
                HStack(spacing: 12) {
                    statPill(
                        value: "\(status.profile.avgCycleLength)",
                        unit: "days",
                        label: "Avg Cycle"
                    )

                    statPill(
                        value: "\(status.currentCycle.bleedingDays)",
                        unit: "days",
                        label: "Period"
                    )

                    statPill(
                        value: store.state.cycleRegularityDisplay,
                        unit: "",
                        label: "Regularity"
                    )
                }

                // Tracking since
                if let trackingSince = store.state.trackingSinceFormatted {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundColor(DesignColors.textPlaceholder)
                        Text("Tracking since \(trackingSince)")
                            .font(.raleway("Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(DesignColors.textPlaceholder)
                    }
                }
            }
            .padding(AppLayout.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
        }
    }

    // MARK: - Wellness Card

    @ViewBuilder
    var wellnessCard: some View {
        if let hbi = store.hbiDashboard, hbi.today != nil {
            VStack(alignment: .leading, spacing: AppLayout.spacingM) {
                sectionHeader(title: "Wellness", icon: "heart.circle")

                HStack(spacing: AppLayout.spacingM) {
                    // HBI Score ring
                    if let score = store.state.hbiScore {
                        ZStack {
                            Circle()
                                .stroke(DesignColors.structure.opacity(0.3), lineWidth: 6)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100.0)
                                .stroke(
                                    LinearGradient(
                                        colors: [DesignColors.accent, DesignColors.accentWarm],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 0) {
                                Text("\(score)")
                                    .font(.raleway("Bold", size: 20, relativeTo: .title2))
                                    .foregroundColor(DesignColors.text)
                                Text("HBI")
                                    .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                                    .foregroundColor(DesignColors.textSecondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hormonal Balance")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                            .foregroundColor(DesignColors.text)

                        if let trend = store.state.hbiTrend {
                            HStack(spacing: 4) {
                                Image(systemName: trend == "up" ? "arrow.up.right" : trend == "down" ? "arrow.down.right" : "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(trend == "up" ? .green : trend == "down" ? DesignColors.accentWarm : DesignColors.textSecondary)

                                Text(trend == "up" ? "Trending up" : trend == "down" ? "Trending down" : "Stable")
                                    .font(.raleway("Regular", size: 13, relativeTo: .caption))
                                    .foregroundColor(DesignColors.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }

                // Week sparkline
                if let weekTrend = hbi.weekTrend, weekTrend.count > 1 {
                    weekSparkline(scores: weekTrend.compactMap { $0.hbiAdjusted })
                }
            }
            .padding(AppLayout.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
        }
    }


// MARK: - Preview

#Preview("Profile - Full Data") {
    NavigationStack {
        ProfileView(
            store: .init(
                initialState: ProfileFeature.State(
                    user: .mock,
                    menstrualStatus: .mock,
                    hbiDashboard: HBIDashboardResponse(
                        today: .mock,
                        weekTrend: [.mock, .mock, .mock, .mock]
                    )
                )
            ) {
                ProfileFeature()
            }
        )
    }
}

#Preview("Profile - Minimal") {
    NavigationStack {
        ProfileView(
            store: .init(
                initialState: ProfileFeature.State(user: .mock)
            ) {
                ProfileFeature()
            }
        )
    }
}
}
