import ComposableArchitecture
import RiveRuntime
import SwiftData
import SwiftUI


// MARK: - Home View

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    @State private var safeAreaTop: CGFloat = 0
    /// Local mirror of `isCalendarVisible` — the parallax offset
    /// animation is driven from this instead of the store so SwiftUI's
    /// animation transaction doesn't cascade into Today's ScrollView
    /// and cause widgets to briefly shift down-then-back when the
    /// calendar dismisses.
    @State private var isCalendarOpen: Bool = false

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { rootGeo in
        ZStack {
            GradientBackground()
                .ignoresSafeArea()

            TabView(selection: $store.selectedTab) {
                // Today Tab
                TodayView(
                    store: store.scope(state: \.todayState, action: \.today)
                )
                .tabItem {
                    Label(
                        HomeFeature.State.Tab.today.title,
                        systemImage: store.selectedTab == .today
                            ? HomeFeature.State.Tab.today.selectedIcon
                            : HomeFeature.State.Tab.today.icon
                    )
                }
                .tag(HomeFeature.State.Tab.today)

                // Chat Tab (Aria)
                ChatView(store: store.scope(state: \.chatState, action: \.chat))
                    .tabItem {
                        Label(
                            HomeFeature.State.Tab.chat.title,
                            systemImage: store.selectedTab == .chat
                                ? HomeFeature.State.Tab.chat.selectedIcon
                                : HomeFeature.State.Tab.chat.icon
                        )
                    }
                    .tag(HomeFeature.State.Tab.chat)

                // Me Tab
                NavigationStack {
                    MeView(
                        store: store.scope(state: \.meState, action: \.me)
                    )
                }
                .tabItem {
                    Label(
                        HomeFeature.State.Tab.me.title,
                        systemImage: store.selectedTab == .me
                            ? HomeFeature.State.Tab.me.selectedIcon
                            : HomeFeature.State.Tab.me.icon
                    )
                }
                .tag(HomeFeature.State.Tab.me)
            }
            .tint(DesignColors.accentWarm)
            // Tell every descendant that Today is not the frontmost
            // visible surface, so continuous animations underneath
            // (hero orb, blob shapes, timeline-driven widgets) can
            // unmount themselves. Any of these is a cover:
            //   - user switched to another tab (TabView keeps the
            //     Today tab alive by design, so the orb would keep
            //     ticking at 30Hz unless we tell it to stop)
            //   - calendar overlay slid on top
            //   - cycle insights overlay slid on top
            //   - cycle journey full-screen cover is up
            //   - latest-recap full-screen cover is up
            // Instruments showed a continuously-running `NyraOrb` as
            // the dominant source of `ViewGraph.beginNextUpdate`
            // work during every one of these states.
            .environment(
                \.isBehindOverlay,
                store.selectedTab != .today
                    || isCalendarOpen
                    || store.isCycleInsightsVisible
                    || store.isCycleJourneyVisible
                    || store.isBodyPatternsVisible
                    || store.isLatestRecapDirectVisible
            )
            .compositingGroup()
            .offset(x: (isCalendarOpen || store.isCycleInsightsVisible || store.isBodyPatternsVisible || store.todayState.calendarState.isShowingSymptomSheet || store.meState.addBond != nil || store.meState.bondReading != nil || store.meState.bondHistory != nil || store.meState.insightHistory != nil || store.meState.meReading != nil) ? -rootGeo.size.width * 0.22 : 0)
            .overlay(
                // MeReading is intentionally excluded — that
                // flow now slides in as a native right-to-left
                // push, and the parent dim made it read as a
                // fade behind the slide. Other overlays
                // (calendar, bond flows, insight history) keep
                // the 0.22 dim so they read as modal-style
                // takeovers rather than navigation.
                Color.black
                    .opacity((isCalendarOpen || store.isCycleInsightsVisible || store.isBodyPatternsVisible || store.todayState.calendarState.isShowingSymptomSheet || store.meState.addBond != nil || store.meState.bondReading != nil || store.meState.bondHistory != nil || store.meState.insightHistory != nil) ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.32), value: isCalendarOpen)
            .animation(.easeInOut(duration: 0.32), value: store.isCycleInsightsVisible)
            .animation(.easeInOut(duration: 0.32), value: store.isBodyPatternsVisible)
            .animation(.easeInOut(duration: 0.32), value: store.todayState.calendarState.isShowingSymptomSheet)
            .animation(.easeInOut(duration: 0.32), value: store.meState.addBond != nil)
            .animation(.easeInOut(duration: 0.32), value: store.meState.bondReading != nil)
            .animation(.easeInOut(duration: 0.32), value: store.meState.bondHistory != nil)
            .animation(.easeInOut(duration: 0.32), value: store.meState.insightHistory != nil || store.meState.meReading != nil)

            // Calendar overlay — animation is scoped to this inner
            // ZStack only so the `.transition` of the calendar doesn't
            // emit a transaction that bleeds back into the parent's
            // sibling views (previously animated Today's hero height
            // while the overlay was sliding off, causing the Rhythm
            // widgets to drift back up at the tail of dismiss).
            ZStack {
                if isCalendarOpen {
                    ZStack {
                        Color.white.ignoresSafeArea()
                        CalendarView(
                            store: store.scope(
                                state: \.todayState.calendarState,
                                action: \.today.calendar
                            )
                        )
                    }
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: isCalendarOpen)
            .zIndex(1)

            // Cycle Insights overlay — slides in from trailing edge like Calendar.
            ZStack {
                if store.isCycleInsightsVisible {
                    CycleInsightsView(
                        store: store.scope(
                            state: \.cycleInsightsState,
                            action: \.cycleInsights
                        )
                    )
                    .background(DesignColors.background.ignoresSafeArea())
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.isCycleInsightsVisible)
            .zIndex(3)

            // Body Patterns overlay — same trailing-slide behaviour as
            // Cycle Insights so the destination feels like a sibling
            // push rather than a modal. Sits on top of Cycle Insights
            // (zIndex 4) because it can be reached from Today directly.
            ZStack {
                if store.isBodyPatternsVisible {
                    BodyPatternsView(
                        store: store.scope(
                            state: \.bodyPatternsState,
                            action: \.bodyPatterns
                        )
                    )
                    .background(DesignColors.background.ignoresSafeArea())
                    .transition(.move(edge: .trailing))
                }
            }
            .offset(x: store.todayState.calendarState.isShowingSymptomSheet ? -rootGeo.size.width * 0.22 : 0)
            .overlay(
                Color.black
                    .opacity(store.todayState.calendarState.isShowingSymptomSheet ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.32), value: store.isBodyPatternsVisible)
            .animation(.easeInOut(duration: 0.32), value: store.todayState.calendarState.isShowingSymptomSheet)
            .zIndex(4)

            // Symptom logging overlay — slides in from the right
            // like Calendar / CycleInsights / BodyPatterns. Lives at
            // the top of the Home stack so it lays cleanly over any
            // sibling overlay (so "Log Symptoms" from BodyPatterns
            // appears above the BodyPatterns overlay rather than
            // forcing it to dismiss).
            ZStack {
                if store.todayState.calendarState.isShowingSymptomSheet {
                    SymptomLoggingSheet(
                        store: store.scope(
                            state: \.todayState.calendarState,
                            action: \.today.calendar
                        )
                    )
                    .background(Color.white.ignoresSafeArea())
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.todayState.calendarState.isShowingSymptomSheet)
            .zIndex(5)

            // Bond History overlay — opens from the BondsCard
            // arrow chip. Sits *below* AddBond (zIndex 7) and
            // BondReading (zIndex 8) so that when a history row
            // is tapped (or "Add a bond" inside history is
            // pressed) the destination overlay slides in OVER
            // this one and history dismisses underneath after the
            // slide — no flash of Home between the two screens.
            ZStack {
                if let historyStore = store.scope(
                    state: \.meState.bondHistory,
                    action: \.me.bondHistory.presented
                ) {
                    BondHistoryView(store: historyStore)
                        .background(DesignColors.background.ignoresSafeArea())
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.meState.bondHistory != nil)
            .zIndex(6)

            // Insight History overlay — opens from the Daily
            // Insight card's arrow chip (or full-card tap). Same
            // trailing-slide treatment as BondHistory, sitting at
            // the same zIndex because the two overlays are
            // mutually exclusive (different cards trigger them).
            ZStack {
                if let insightStore = store.scope(
                    state: \.meState.insightHistory,
                    action: \.me.insightHistory.presented
                ) {
                    InsightHistoryView(store: insightStore)
                        .background(DesignColors.background.ignoresSafeArea())
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.meState.insightHistory != nil)
            .zIndex(6)

            // Add Bond overlay — Me tab's "+ Add bond" flow. Same
            // trailing-slide pattern as the other in-Home overlays
            // so it covers the tab bar and the underlying Me screen
            // parallaxes with everything else. The state lives on
            // MeFeature (`meState.addBond`) so the scope reaches in
            // via `\.meState.addBond` + `\.me.addBond.presented`.
            ZStack {
                if let addBondStore = store.scope(
                    state: \.meState.addBond,
                    action: \.me.addBond.presented
                ) {
                    AddBondView(
                        store: addBondStore,
                        onDismiss: { store.send(.me(.dismissAddBond)) }
                    )
                    .background(DesignColors.background.ignoresSafeArea())
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.meState.addBond != nil)
            .zIndex(7)

            // Bond Reading overlay — opens when a bond is tapped
            // (or whenever `meState.bondReading` is set). Sits at
            // the top of the overlay stack (zIndex 8) so it sits
            // over AddBond and BondHistory cleanly.
            //
            // Uses a cross-fade (opacity + a hair of scale) rather
            // than the trailing slide the other overlays use. The
            // reading is typically opened *after* the Generating
            // screen has filled the canvas with a warm curtain;
            // fading in inside that curtain reads as the reading
            // "materialising" out of it, while a slide-from-right
            // would feel like an unrelated push across it.
            // BondHistory → Reading also goes through this fade,
            // which is gentler than a hard slide for a back-stack
            // forward push.
            ZStack {
                if let readingStore = store.scope(
                    state: \.meState.bondReading,
                    action: \.me.bondReading.presented
                ) {
                    BondReadingView(store: readingStore)
                        .background(DesignColors.background.ignoresSafeArea())
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 1.015, anchor: .center)
                            )
                        )
                }
            }
            .animation(.easeInOut(duration: 0.42), value: store.meState.bondReading != nil)
            .zIndex(8)

            // Me Reading overlay — user's personal reading flow
            // opened from the StoryHeroCard "decode" chevron.
            // Slides in from the trailing edge so it reads as a
            // native right-to-left push instead of the previous
            // cross-fade — the chevron itself telegraphs forward
            // navigation, and the fade was disorienting.
            ZStack {
                if let meReadingStore = store.scope(
                    state: \.meState.meReading,
                    action: \.me.meReading.presented
                ) {
                    MeReadingView(store: meReadingStore)
                        .background(DesignColors.background.ignoresSafeArea())
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: store.meState.meReading != nil)
            .zIndex(9)

            // Initial profile bootstrap — subtle non-blocking top indicator.
            // Tabs stay interactive; hero already has its own skeleton state.
            ZStack {
                if store.isLoading && store.user == nil {
                    VStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(DesignColors.accentWarm)
                            .padding(.top, 8)
                            .accessibilityLabel("Loading your profile")
                            .accessibilityAddTraits(.updatesFrequently)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
            .zIndex(2)
        }
        .onChange(of: store.todayState.isCalendarVisible) { _, newValue in
            // Raw assignment — no `withAnimation` here. The animation
            // is on the `.animation(_, value: isCalendarOpen)` modifier
            // scoped to just the TabView's offset/overlay, so the
            // transaction can't leak into sibling views.
            isCalendarOpen = newValue
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isCycleJourneyVisible },
            set: { if !$0 { store.send(.cycleJourney(.delegate(.dismiss))) } }
        )) {
            CycleJourneyView(
                store: store.scope(
                    state: \.cycleJourneyState,
                    action: \.cycleJourney
                )
            )
            .background(DesignColors.background.ignoresSafeArea())
        }
        // Direct-recap deep-link from Home's Latest Story tile. Shows
        // the recap immediately over Home (single slide-up animation)
        // instead of going Home → Journey → Recap (double animation).
        .fullScreenCover(isPresented: Binding(
            get: { store.isLatestRecapDirectVisible },
            set: { if !$0 { store.send(.cycleJourney(.recapDismissed)) } }
        )) {
            // ZStack with a warm backdrop under AriaRecapStories: when
            // the close button clears `state.recap`, the recap view
            // renders empty — this backdrop keeps the cover solid during
            // the slide-down animation instead of flashing white.
            ZStack {
                DesignColors.background.ignoresSafeArea()
                AriaRecapStories(
                    store: store.scope(
                        state: \.cycleJourneyState,
                        action: \.cycleJourney
                    )
                )
            }
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .task {
            store.send(.onAppear)
        }
        } // GeometryReader
    }


}


// MARK: - Preview


#Preview {
    HomeView(
        store: .init(initialState: HomeFeature.State(user: .mock)) {
            HomeFeature()
        }
    )
}
