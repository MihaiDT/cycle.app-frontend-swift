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
                    ProfileView(
                        store: store.scope(state: \.profileState, action: \.profile)
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
                    || store.isLatestRecapDirectVisible
            )
            .compositingGroup()
            .offset(x: (isCalendarOpen || store.isCycleInsightsVisible) ? -rootGeo.size.width * 0.22 : 0)
            .overlay(
                Color.black
                    .opacity((isCalendarOpen || store.isCycleInsightsVisible) ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.32), value: isCalendarOpen)
            .animation(.easeInOut(duration: 0.32), value: store.isCycleInsightsVisible)

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
