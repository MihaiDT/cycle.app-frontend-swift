import ComposableArchitecture
import Inject
import SwiftData
import SwiftUI

// MARK: - Today View

public struct TodayView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<TodayFeature>

    @State private var showHero = false
    @State private var showContent = false
    @State private var selectedDate: Date?
    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollY: CGFloat?
    @State private var safeAreaTop: CGFloat = 0
    public init(store: StoreOf<TodayFeature>) {
        self.store = store
    }

    private static let confirmDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt
    }()

    // MARK: - Layout Constants

    private let expandedHeroHeight: CGFloat = 290
    private let collapsedHeroHeight: CGFloat = 64
    private let collapseThreshold: CGFloat = 260

    /// Collapse progress: 0 = expanded, 1 = collapsed. Driven by scroll offset.
    /// Steep S-curve so it snaps visually — stays near 0/1, jumps through middle.
    private var collapseProgress: CGFloat {
        let t = min(max(scrollOffset / collapseThreshold, 0), 1)
        // Steep logistic-style curve: t²/(t²+(1-t)²)
        let tSq = t * t
        let inv = (1 - t) * (1 - t)
        let denom = tSq + inv
        return denom > 0 ? tSq / denom : 0
    }

    private var currentHeroHeight: CGFloat {
        expandedHeroHeight + (collapsedHeroHeight - expandedHeroHeight) * collapseProgress + safeAreaTop
    }

    /// Spacer height that keeps content pinned to hero bottom during collapse.
    /// Matches scrollOffset 1:1 during collapse, then caps so normal scrolling resumes.
    private var collapseCompensation: CGFloat {
        min(scrollOffset, collapseThreshold)
    }

    public var body: some View {
        GeometryReader { rootGeo in
        VStack(spacing: 0) {
            // MARK: Sticky Hero (above scroll — content never goes behind it)
            if let cycle = store.cycle, store.hasCompletedCalendarLoad {
                CycleHeroView(
                    cycle: cycle,
                    selectedDate: $selectedDate,
                    isRefreshing: store.isRefreshingCycleData,
                    isSynced: store.syncStatus == .synced,
                    onEditPeriod: { store.send(.calendarTapped) },
                    onLogPeriod: {
                        let date = selectedDate ?? Calendar.current.startOfDay(for: Date())
                        store.send(.logPeriodTapped(date))
                    },
                    onCalendarTapped: { store.send(.calendarTapped) },
                    hasNotification: store.recapBannerMonth != nil,
                    onNotificationTapped: {
                        store.send(.notificationsTapped)
                    },
                    collapseProgress: collapseProgress,
                    safeAreaTop: safeAreaTop,
                    aiWellnessMessage: store.wellnessMessage,
                    isLoadingWellnessMessage: store.isLoadingWellnessMessage
                )
                .opacity(showHero ? 1 : 0)
                .allowsHitTesting(true)
                .zIndex(1)
            } else if store.menstrualStatus != nil, store.menstrualStatus?.hasCycleData == false {
                // No cycle data — prompt to log first period
                noCycleDataHero
                    .opacity(showHero ? 1 : 0)
            } else {
                // Skeleton hero while cycle data loads
                heroSkeleton
                    .opacity(showHero ? 1 : 0)
            }

            // MARK: Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Scroll tracker (must be direct child with non-zero height)
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .global).minY
                            )
                    }
                    .frame(height: 1)

                    // Compensate for hero collapse — pins content to hero bottom
                    // Use transaction to prevent this height change from feeding back into scroll offset
                    if store.cycle != nil {
                        Color.clear.frame(height: collapseCompensation)
                            .transaction { $0.animation = nil }
                    }

                    // MARK: Content
                    VStack(spacing: 0) {
                        // Silent dashboard reload indicator — only when content already exists.
                        // Initial loads are covered by the hero skeleton; this covers refreshes
                        // triggered by check-ins, mood arcs, etc. Non-blocking, tasteful.
                        if store.isLoadingDashboard, store.dashboard != nil {
                            dashboardRefreshIndicator
                                .padding(.top, AppLayout.spacingM)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .accessibilityLabel("Refreshing dashboard")
                        }

                        // Challenge in progress banner
                        if case let .inProgress(startedAt, timerEndDate) = store.dailyChallengeState.challengeState,
                           let challenge = store.dailyChallengeState.challenge {
                            ChallengeInProgressBanner(
                                challengeTitle: challenge.challengeTitle,
                                challengeCategory: challenge.challengeCategory,
                                timerStartDate: startedAt,
                                timerEndDate: timerEndDate,
                                onDone: { store.send(.dailyChallenge(.continueTapped)) }
                            )
                            .padding(.top, AppLayout.spacingL)
                        }

                        if !store.cardStackState.cards.isEmpty || store.cardStackState.isLoading {
                            CardStackView(
                                store: store.scope(
                                    state: \.cardStackState,
                                    action: \.cardStack
                                )
                            )
                            .padding(.top, AppLayout.spacingL)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }

                        VerticalSpace.xl

                        // Journey preview
                        if let cycle = store.cycle {
                            JourneyPreviewSection(
                                cycleCount: cycle.cycleDay > 0 ? max(1, cycle.cycleDay / cycle.cycleLength) : 1,
                                currentCycleNumber: cycle.cycleDay > 0 ? max(1, cycle.cycleDay / cycle.cycleLength) : 1,
                                onTap: { store.send(.delegate(.openCycleJourney)) }
                            )
                            .padding(.horizontal, AppLayout.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 24)
                        }

                        VerticalSpace.xxl
                    }
                }
            }
            .scrollTargetBehavior(CollapseSnapBehavior(threshold: collapseThreshold))
            .trackingScrollOffset($scrollOffset)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                // iOS 17 fallback only
                if #unavailable(iOS 18.0) {
                    if initialScrollY == nil { initialScrollY = value }
                    scrollOffset = max(0, (initialScrollY ?? 0) - value)
                }
            }
            .refreshable {
                store.send(.refreshTapped)
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: Binding(
            get: { store.isNotificationsPanelVisible },
            set: { if !$0 { store.send(.notificationsPanelDismissed) } }
        )) {
            NotificationsPanel(
                recapMonth: store.recapBannerMonth,
                onRecapTapped: {
                    store.send(.notificationsPanelDismissed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        store.send(.delegate(.openCycleJourney))
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppLayout.cornerRadiusL)
            .presentationBackground(DesignColors.background)
        }
        .sheet(isPresented: Binding(
            get: { store.isRecapSheetVisible },
            set: { if !$0 { store.send(.recapSheetDismissed) } }
        )) {
            if let month = store.recapBannerMonth {
                AriaRecapSheet(monthName: month) {
                    store.send(.recapSheetDismissed)
                    store.send(.delegate(.openCycleJourney))
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
                .presentationBackground(DesignColors.background)
            }
        }
        .sheet(item: $store.scope(state: \.checkIn, action: \.checkIn)) { checkInStore in
            DailyCheckInView(store: checkInStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
        }
        .sheet(item: $store.scope(state: \.moodArc, action: \.moodArc)) { moodStore in
            MoodArcView(store: moodStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
        }
        .modifier(DailyGlowPresentations(store: store))
        .confirmationDialog(
            "Log your period",
            isPresented: $store.isShowingLateConfirmSheet,
            titleVisibility: .visible
        ) {
            if let expectedDate = store.cycle?.effectiveExpectedDate {
                Button("Started on \(Self.confirmDateFormatter.string(from: expectedDate))") {
                    store.send(.latePeriodStartedOnPredicted)
                }
            }
            Button("Started on a different date") {
                store.send(.latePeriodStartedDifferent)
            }
            Button("It hasn't started yet", role: .cancel) {
                store.send(.latePeriodNotStarted)
            }
        } message: {
            Text("Did your new cycle start around the expected date, or would you like to pick the correct dates?")
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoadingDashboard)
        .onChange(of: store.hasAppeared) { _, appeared in
            guard appeared else { return }
            triggerStaggeredAnimations()
        }
        .onChange(of: store.isRefreshingCycleData) { _, isRefreshing in
            // Content stays visible during refresh — hero wave is the only indicator.
            // Only ensure showContent is true when refresh ends (covers edge case
            // where refresh starts before initial staggered animation completes).
            if !isRefreshing && !showContent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showContent = true
                    }
                }
            }
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .enableInjection()
        } // GeometryReader
    }

    // MARK: - Staggered Animations

    private func triggerStaggeredAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            showHero = true
        }
        // Content appears after hero wave settles — real delay, not animation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
    }

    // MARK: - No Cycle Data Hero

    @ViewBuilder
    private var noCycleDataHero: some View {
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
                .padding(.horizontal, AppLayout.horizontalPadding)
            }
        }
        .frame(height: 320)
    }

    // MARK: - Dashboard Refresh Indicator (subtle pill for silent reloads)

    @ViewBuilder
    private var dashboardRefreshIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(DesignColors.accentWarm)
            Text("Refreshing…")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(.horizontal, 14)
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
    private var heroSkeleton: some View {
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
