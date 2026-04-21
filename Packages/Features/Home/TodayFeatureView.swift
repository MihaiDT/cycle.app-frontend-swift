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
    @State private var safeAreaTop: CGFloat = 0
    /// When non-nil, overrides `collapseProgress` with a pinned value.
    /// Captured the moment the calendar overlay appears and released
    /// only after it fully dismisses, so the hero height can't
    /// recompute from live scroll changes while something is sliding
    /// in front of Today — the real cause of the Rhythm-widget bounce.
    @State private var frozenCollapseProgress: CGFloat?
    /// Current page of the Rhythm-section widget carousel.
    /// 0 = Rhythm (wellness), 1 = Journey. Future widgets slot in after.
    @State private var rhythmPage: Int = 0
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

    // MARK: - Wellness Section (W2)

    /// Home's wellness card + optional Aria voice line. Three states:
    /// - Resolved HBI → tappable widget with trend + optional Aria line
    /// - Actively loading (no dashboard yet) → skeleton
    /// - No check-in today → empty-state widget that nudges toward the
    ///   daily check-in instead of a permanent shimmer.
    /// Widget-level carousel pairing Rhythm with Journey (and any future
    /// widget pages). Section header's title and trailing dots track the
    /// visible page — no full-page paging, only the widget area swipes.
    private var widgetSectionPageCount: Int { 2 }

    private var widgetSectionTitle: String {
        switch rhythmPage {
        case 1:  return "Journey"
        default: return "Rhythm"
        }
    }

    @ViewBuilder
    private var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom section header with a staggered letter reveal so the
            // title animates when the user pages between widgets.
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                StaggeredTitle(text: widgetSectionTitle)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 10)

            HomeWidgetCarousel(
                currentIndex: $rhythmPage,
                pageCount: widgetSectionPageCount,
                horizontalPadding: AppLayout.horizontalPadding
            ) { index in
                switch index {
                case 0: rhythmPageContent
                case 1: journeyPageContent
                default: EmptyView()
                }
            }

            // Dots centered below the carousel — more visible than a
            // trailing slot on the section header, and give users a clear
            // handle to tap between pages.
            HStack {
                Spacer()
                HomeWidgetCarouselDots(
                    pageCount: widgetSectionPageCount,
                    currentIndex: $rhythmPage
                )
                Spacer()
            }
            .padding(.top, 14)
        }
    }

    /// Rhythm page — existing wellness widget + two ritual tiles.
    /// Trailing Spacer anchors content to the top so the Rhythm tiles
    /// don't stretch when the carousel sizes to the taller Journey page.
    @ViewBuilder
    private var rhythmPageContent: some View {
        VStack(spacing: 0) {
            wellnessBody
            Spacer(minLength: 0)
        }
    }

    /// Journey page — 3 destination boxes: Journey (recap stories),
    /// Cycle Stats (averages & trends), Body Patterns (symptoms & signals).
    /// Kept structurally symmetric with the Rhythm page (hero + tile row)
    /// so the carousel height stays constant across pages.
    @ViewBuilder
    private var journeyPageContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                JourneyDestinationTile(
                    kind: .stats,
                    stat: cycleStatsPreview,
                    onTap: { store.send(.delegate(.openCycleStats)) }
                )

                JourneyDestinationTile(
                    kind: .body,
                    stat: bodyPatternsPreview,
                    onTap: { store.send(.delegate(.openBodyPatterns)) }
                )
            }

            JourneyDestinationCard(
                subtitle: journeyCardSubtitle,
                isNew: store.recapBannerMonth != nil,
                onTap: { store.send(.delegate(.openCycleJourney)) }
            )

            // Anchor content to the top so the carousel doesn't stretch
            // child tiles when a sibling page happens to be shorter.
            Spacer(minLength: 0)
        }
    }

    private var journeyCardSubtitle: String {
        if let month = store.recapBannerMonth {
            return "Your \(month) recap is ready."
        }
        return "Every cycle, a chapter of your story."
    }

    private var cycleStatsPreview: String {
        guard let avg = store.menstrualStatus?.profile.avgCycleLength, avg > 0 else {
            return "—"
        }
        return "~\(avg)d"
    }

    private var bodyPatternsPreview: String {
        guard let phase = store.wellnessPhase else { return "—" }
        return phase.rawValue.capitalized
    }

    /// Wellness section body. Layout mirrors Apple Home widgets / Cal AI:
    /// one big hero widget (ring + score) on top, a grid of smaller ritual
    /// tiles below. The widget only appears after the daily check-in lands
    /// — before then, the tiles are the primary surface so the user has
    /// two obvious, equal-weight things to tap.
    @ViewBuilder
    private var wellnessBody: some View {
        VStack(spacing: 12) {
            if store.hasCompletedCheckIn, let adjusted = store.wellnessAdjusted {
                WellnessWidget(
                    adjusted: adjusted,
                    trendVsBaseline: store.wellnessTrendVsBaseline,
                    phase: store.wellnessPhase,
                    cycleDay: store.wellnessCycleDay,
                    sourceLabel: store.wellnessSourceLabel,
                    onDetailTap: { store.send(.wellnessTapped) }
                )
            } else if store.isLoadingDashboard, store.dashboard == nil {
                WellnessWidgetSkeleton()
            } else {
                wellnessAwaitingCard
            }

            ritualTilesRow

            if store.shouldShowAriaVoice {
                AriaVoiceLine(phase: store.wellnessPhase)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Pre-check-in placeholder that sits in the widget slot until the
    /// score is ready. Mirrors the widget's shape and meta row so the
    /// section layout stays stable and the tiles don't drift upward.
    @ViewBuilder
    private var wellnessAwaitingCard: some View {
        let meta: String? = {
            guard let phase = store.wellnessPhase, phase != .late else { return nil }
            if let day = store.wellnessCycleDay {
                return "\(phase.displayName.uppercased()) · DAY \(day)"
            }
            return phase.displayName.uppercased()
        }()

        VStack(alignment: .leading, spacing: 0) {
            if let meta {
                Text(meta)
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(0.6)
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.bottom, 12)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your rhythm is waiting")
                        .font(.raleway("Bold", size: 22, relativeTo: .title3))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Start with today's rituals below to unlock your score.")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 6, dash: [3, 5])
                        )
                        .foregroundStyle(DesignColors.text.opacity(0.12))
                        .frame(width: 84, height: 84)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DesignColors.text.opacity(0.25))
                }
            }
        }
        .padding(18)
        .widgetCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rhythm is waiting. Start with today's rituals to unlock your score.")
    }

    /// Two Cal-AI-style tiles side by side: check-in + moment. Always visible
    /// so the day's rituals have a stable home — the widget above them comes
    /// and goes based on whether the score is ready, but the call-to-action
    /// surface is constant.
    @ViewBuilder
    private var ritualTilesRow: some View {
        let checkInDone = store.hasCompletedCheckIn
        let momentDone: Bool = {
            if case .completed = store.dailyChallengeState.challengeState { return true }
            return false
        }()
        let challenge = store.dailyChallengeState.challenge
        let momentSubtitle = challenge?.challengeTitle ?? "Today's gentle moment"
        let momentIcon = challenge?.tileIconName ?? "sparkles"

        HStack(spacing: 12) {
            WellnessRitualTile(
                title: "Check-in",
                subtitle: "How do you feel?",
                iconName: "heart.fill",
                isDone: checkInDone,
                onTap: { store.send(.checkInTapped) }
            )

            WellnessRitualTile(
                title: "Your moment",
                subtitle: momentSubtitle,
                iconName: momentIcon,
                isDone: momentDone,
                onTap: { store.send(.dailyChallenge(.doItTapped)) }
            )
        }
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

    // MARK: - Log Symptoms Pill
    //
    // Temporary home for the "Log Symptoms" quick action — used to live
    // on the calendar's floating bottom bar. Tapping opens the calendar
    // overlay and immediately surfaces today's symptom sheet.

    // MARK: - Symptom Pattern Section
    //
    // Editorial "what your body's been saying" block under the widget
    // carousel. Pairs a short AI-flavoured pattern hint with the Log
    // Symptoms CTA — gives symptom tracking its own home on Today
    // rather than a floating pill above everything.

    @ViewBuilder
    private var symptomPatternSection: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingM) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("Symptom pattern")
                    .font(.raleway("Bold", size: 22, relativeTo: .title3))
                    .tracking(-0.2)
                    .foregroundStyle(DesignColors.text)

                Spacer()

                Text("Last 7 days".uppercased())
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
            }

            // Pattern card
            VStack(alignment: .leading, spacing: AppLayout.spacingM) {
                Text("No patterns yet")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)

                Text("Log a few symptoms and I'll start noticing how your body shows up across your cycle.")
                    .font(.raleway("Regular", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                logSymptomsPill
                    .padding(.top, AppLayout.spacingS)
            }
            .padding(AppLayout.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .fill(Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .strokeBorder(DesignColors.accentWarm.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
    }

    private var logSymptomsPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            store.send(.logSymptomsTapped, animation: .appBalanced)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Log Symptoms")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
            }
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .fixedSize()
            .background {
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .shadow(color: DesignColors.accentWarm.opacity(0.12), radius: 8, x: 0, y: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log symptoms for today")
        .accessibilityHint("Opens the symptoms sheet")
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

