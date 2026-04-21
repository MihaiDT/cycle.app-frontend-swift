import ComposableArchitecture
import SwiftUI

// MARK: - Profile Feature

@Reducer
public struct ProfileFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var user: User?
        public var menstrualStatus: MenstrualStatusResponse?
        public var hbiDashboard: HBIDashboardResponse?
        public var glowProfile: GlowProfileSnapshot?

        public init(
            user: User? = nil,
            menstrualStatus: MenstrualStatusResponse? = nil,
            hbiDashboard: HBIDashboardResponse? = nil
        ) {
            self.user = user
            self.menstrualStatus = menstrualStatus
            self.hbiDashboard = hbiDashboard
        }

        // MARK: - Computed

        var cyclePhase: CyclePhase? {
            guard let phase = menstrualStatus?.currentCycle.phase else { return nil }
            return CyclePhase(rawValue: phase)
        }

        var memberSinceFormatted: String? {
            guard let user else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: user.createdAt)
        }

        var trackingSinceFormatted: String? {
            guard let date = menstrualStatus?.profile.trackingSince else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }

        var cycleRegularityDisplay: String {
            guard let reg = menstrualStatus?.profile.cycleRegularity else { return "Unknown" }
            switch reg {
            case "regular": return "Regular"
            case "somewhat_regular": return "Somewhat Regular"
            case "irregular": return "Irregular"
            default: return reg.capitalized
            }
        }

        var hbiScore: Int? {
            hbiDashboard?.today?.hbiAdjusted
        }

        var hbiTrend: String? {
            hbiDashboard?.today?.trendDirection
        }
    }

    public enum Action: Sendable {
        case loadGlowProfile
        case glowProfileLoaded(GlowProfileSnapshot)
        case logoutTapped
        case deleteChatDataTapped
        case chatDataDeleted
        case resetAnonymousIDTapped
        case anonymousIDReset
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
        }
    }

    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.glowLocal) var glowLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadGlowProfile:
                return .run { [glowLocal] send in
                    let profile = try await glowLocal.getProfile()
                    await send(.glowProfileLoaded(profile))
                }

            case let .glowProfileLoaded(profile):
                state.glowProfile = profile
                return .none

            case .logoutTapped:
                return .send(.delegate(.didLogout))

            case .deleteChatDataTapped:
                let id = anonymousID.getID()
                return .run { send in
                    // Call server to delete all anonymous data
                    let url = URL(string: "https://dth-backend-277319586889.us-central1.run.app/anonymous/\(id)/all")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    _ = try? await URLSession.shared.data(for: request)
                    await send(.chatDataDeleted)
                }

            case .chatDataDeleted:
                return .none

            case .resetAnonymousIDTapped:
                _ = anonymousID.rotateID()
                return .send(.anonymousIDReset)

            case .anonymousIDReset:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

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
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, AppLayout.spacingM)
            }
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.loadGlowProfile) }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
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
    private var glowSection: some View {
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

    private func glowStat(value: String, label: String) -> some View {
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
    private var cycleOverviewCard: some View {
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
                    .padding(.horizontal, 14)
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
    private var wellnessCard: some View {
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

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Settings", icon: "gearshape")
                .padding(.bottom, AppLayout.spacingS)

            settingsRow(icon: "bell", title: "Notifications", subtitle: "Reminders & alerts")
            settingsDivider
            settingsRow(icon: "person.text.rectangle", title: "Account", subtitle: "Email & password")
            settingsDivider
            settingsRow(icon: "lock.shield", title: "Privacy", subtitle: "Data & permissions")
            settingsDivider
            settingsRow(icon: "apple.logo", title: "HealthKit", subtitle: "Connected data sources")
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: nil)
            settingsDivider
            settingsRow(icon: "doc.text", title: "Terms of Service", subtitle: nil)
            settingsDivider
            settingsRow(icon: "hand.raised", title: "Privacy Policy", subtitle: nil)
            settingsDivider

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(width: 28)

                Text("Version")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundColor(DesignColors.text)

                Spacer()

                Text(appVersion)
                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                    .foregroundColor(DesignColors.textPlaceholder)
            }
            .padding(.vertical, 14)
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
    }

    // MARK: - Privacy Actions

    private var privacyActionsSection: some View {
        VStack(spacing: 12) {
            profileActionButton(
                icon: "trash",
                title: "Delete Chat History",
                subtitle: "Remove all Aria conversations from server",
                action: { store.send(.deleteChatDataTapped) }
            )

            profileActionButton(
                icon: "arrow.triangle.2.circlepath",
                title: "Reset Anonymous ID",
                subtitle: "Old conversations become unlinkable",
                action: { store.send(.resetAnonymousIDTapped) }
            )

            profileActionButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Reset App",
                subtitle: "Delete all local data and start fresh",
                action: { store.send(.logoutTapped) },
                isDestructive: true
            )
        }
    }

    private func profileActionButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    Text(subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textSecondary)
                }
                Spacer()
            }
            .foregroundColor(isDestructive ? .red.opacity(0.8) : DesignColors.accentWarm)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                            .strokeBorder(
                                (isDestructive ? Color.red : DesignColors.accentWarm).opacity(0.3),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignColors.accentSecondary)
            Text(title)
                .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                .foregroundColor(DesignColors.text)
            Spacer()
        }
    }

    private func statPill(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.raleway("Bold", size: 18, relativeTo: .headline))
                    .foregroundColor(DesignColors.text)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                        .foregroundColor(DesignColors.textSecondary)
                }
            }
            Text(label)
                .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                .foregroundColor(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusS)
                .fill(Color.white.opacity(0.3))
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignColors.accentSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundColor(DesignColors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textPlaceholder)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignColors.textPlaceholder)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(DesignColors.divider.opacity(0.4))
            .frame(height: 0.5)
            .padding(.leading, 40)
    }

    private func weekSparkline(scores: [Int]) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 32
            let maxScore = max(scores.max() ?? 100, 1)
            let minScore = max(scores.min() ?? 0, 0)
            let range = max(CGFloat(maxScore - minScore), 1)

            Path { path in
                for (index, score) in scores.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(scores.count - 1, 1))
                    let y = height - (CGFloat(score - minScore) / range) * height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [DesignColors.accent, DesignColors.accentWarm],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 32)
    }

    private func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
