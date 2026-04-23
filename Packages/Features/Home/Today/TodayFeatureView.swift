import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today View

public struct TodayView: View {
    @Bindable var store: StoreOf<TodayFeature>

    @State private var showHero = false
    @State private var showContent = false
    @State private var selectedDate: Date?
    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollY: CGFloat?
    @State var safeAreaTop: CGFloat = 0
    /// When non-nil, overrides `collapseProgress` with a pinned value.
    /// Captured the moment the calendar overlay appears and released
    /// only after it fully dismisses, so the hero height can't
    /// recompute from live scroll changes while something is sliding
    /// in front of Today — the real cause of the Rhythm-widget bounce.
    @State private var frozenCollapseProgress: CGFloat?
    /// Current page of the Rhythm-section widget carousel.
    /// 0 = Rhythm (wellness), 1 = Journey. Future widgets slot in after.
    @State var rhythmPage: Int = 0
    public init(store: StoreOf<TodayFeature>) {
        self.store = store
    }

    private static let confirmDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt
    }()

    // MARK: - Layout Constants

    let expandedHeroHeight: CGFloat = 290
    private let collapsedHeroHeight: CGFloat = 64
    private let collapseThreshold: CGFloat = 260

    /// Live collapse progress from scroll.
    private var liveCollapseProgress: CGFloat {
        min(max(scrollOffset / collapseThreshold, 0), 1)
    }

    /// Effective progress the hero actually sees — pinned value if
    /// the calendar overlay is active, otherwise the live scroll-driven
    /// value. This is the lock that keeps Today's layout frozen while
    /// something slides over it.
    private var collapseProgress: CGFloat {
        frozenCollapseProgress ?? liveCollapseProgress
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
        // Prefer the synchronous geometry reading over the async `onAppear`
        // state write — otherwise the hero renders under the notch on first
        // paint and "jumps down" once onAppear fires (visible for ~1 frame).
        let liveSafeAreaTop = max(rootGeo.safeAreaInsets.top, safeAreaTop)

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
                    safeAreaTop: liveSafeAreaTop,
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

                        // MARK: Wellness widget (W2) — adjusted HBI hero card.
                        // Renders once cycle data is available so phase + day
                        // meta are trustworthy. Skeleton fills the same shape
                        // on the very first load so the layout never jumps.
                        if store.cycle != nil {
                            wellnessSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 16)
                        }

                        if !store.yourDayState.previews.isEmpty
                            || store.yourDayState.isLoading
                            || store.yourDayState.hasLoadError
                        {
                            YourDayView(
                                store: store.scope(
                                    state: \.yourDayState,
                                    action: \.yourDay
                                )
                            )
                            .padding(.top, AppLayout.spacingL)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }

                        // MARK: Symptom Pattern section — sits after the
                        // other widgets so it reads as a follow-up
                        // "here's what I noticed" block plus the Log
                        // Symptoms CTA.
                        symptomPatternSection
                            .padding(.top, AppLayout.spacingXL)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        VerticalSpace.xxl
                    }
                }
            }
            .scrollTargetBehavior(CollapseSnapBehavior(threshold: collapseThreshold))
            .trackingScrollOffset($scrollOffset)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                // iOS 17 fallback only
                if #unavailable(iOS 18.0) {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        if initialScrollY == nil { initialScrollY = value }
                        scrollOffset = max(0, (initialScrollY ?? 0) - value)
                    }
                }
            }
            // Pull-to-refresh intentionally omitted — when the calendar
            // overlay dismissed, SwiftUI's refreshable was briefly
            // animating the scroll content downward as if a refresh
            // had started, producing a visible bounce under the hero.
            // Data refreshes are driven by onAppear / state changes,
            // so the gesture isn't needed here.
        }
        .ignoresSafeArea(edges: .top)
        // Log symptoms sheet — surfaced directly on Home without
        // routing through the calendar overlay. Still reads state and
        // dispatches actions via the calendarState scope so the
        // underlying logic is unchanged.
        .sheet(
            isPresented: Binding(
                get: { store.calendarState.isShowingSymptomSheet },
                set: { if !$0 { store.send(.calendar(.symptomSheetDismissed)) } }
            )
        ) {
            SymptomLoggingSheet(
                store: store.scope(state: \.calendarState, action: \.calendar)
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppLayout.cornerRadiusXL)
            .presentationBackground(.white)
            .presentationBackgroundInteraction(.disabled)
        }
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
        .sheet(item: Binding(
            get: { store.dayDetailPayload },
            set: { if $0 == nil { store.send(.dayDetailDismissed) } }
        )) { payload in
            DayDetailView(
                payload: payload,
                onDismiss: { store.send(.dayDetailDismissed) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppLayout.cornerRadiusL)
            .presentationBackground(DesignColors.background)
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
        .onChange(of: store.isCalendarVisible) { _, isVisible in
            if isVisible {
                // Freeze layout the moment the overlay starts coming in
                frozenCollapseProgress = liveCollapseProgress
            } else {
                // Release AFTER the overlay's dismiss animation fully
                // settles — ~350ms covers the 0.32s transition + a
                // small buffer so any trailing scrollOffset noise
                // from the layout shuffle doesn't re-animate the hero.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 360_000_000)
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        frozenCollapseProgress = nil
                    }
                }
            }
        }
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

}
