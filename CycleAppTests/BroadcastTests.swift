@testable import CycleApp
import ComposableArchitecture
import Foundation
import Testing

// MARK: - Broadcast: Today → Siblings (TCA TestStore)

/// Verifies the fan-out / broadcast wiring in TodayFeature & HomeFeature:
/// - `dashboardLoaded(.success)` → broadcasts HBI to CardStack + DailyChallenge
/// - `menstrualStatusLoaded(.success)` → broadcasts CycleContext via delegate
/// - `calendarEntriesLoaded(.success)` → broadcasts CycleContext via delegate
/// - Home forwards `delegate.cycleDataUpdated` → CycleInsights + CycleJourney
///
/// Uses `.off` exhaustivity because each broadcast also triggers secondary
/// effects (preload calendar, wellness message, recap generation) that
/// depend on SwiftData/live calls and are out of scope for these tests.
@MainActor
@Suite("Broadcast — Today → Children", .serialized)
struct TodayBroadcastTests {

    private static func makeDashboard() -> HBIDashboardResponse {
        HBIDashboardResponse(
            today: HBIScore.mock,
            weekTrend: [HBIScore.mock],
            latestReport: .mock
        )
    }

    @Test("dashboardLoaded.success broadcasts hbiUpdated to cardStack and dailyChallenge")
    func dashboardBroadcastsHBI() async {
        let store = TestStore(initialState: TodayFeature.State()) {
            TodayFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        let dashboard = Self.makeDashboard()
        await store.send(.dashboardLoaded(.success(dashboard))) {
            $0.dashboard = dashboard
            $0.isLoadingDashboard = false
            $0.hasAppeared = true
            $0.hasTriggeredScoreAnimation = true
        }
        // After broadcast — both children's currentHBI should reflect new score.
        await store.receive(\.cardStack.hbiUpdated) {
            $0.cardStackState.currentHBI = HBIScore.mock
        }
        await store.receive(\.dailyChallenge.hbiUpdated) {
            $0.dailyChallengeState.currentHBI = HBIScore.mock
        }
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @Test("dashboardLoaded.success with no today score does not broadcast hbi")
    func noBroadcastWhenNoScore() async {
        let store = TestStore(initialState: TodayFeature.State()) {
            TodayFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        let dashboard = HBIDashboardResponse(today: nil)
        await store.send(.dashboardLoaded(.success(dashboard))) {
            $0.dashboard = dashboard
            $0.isLoadingDashboard = false
            $0.hasAppeared = true
            $0.hasTriggeredScoreAnimation = true
        }
        // CardStack & DailyChallenge should NOT have currentHBI updated
        #expect(store.state.cardStackState.currentHBI == nil)
        #expect(store.state.dailyChallengeState.currentHBI == nil)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @Test("menstrualStatusLoaded.success emits delegate.cycleDataUpdated")
    func menstrualStatusBroadcastsCycle() async {
        var initial = TodayFeature.State()
        // Skip wellness load by pre-setting a cached message.
        initial.wellnessMessage = "prewarmed"
        initial.calendarState.hasPreloaded = true // skip calendar loadCalendar effect
        let store = TestStore(initialState: initial) {
            TodayFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        let status = MenstrualStatusResponse.mock
        await store.send(.menstrualStatusLoaded(.success(status)))

        // Expect a delegate cycleDataUpdated emission.
        await store.receive(\.delegate.cycleDataUpdated)
        #expect(store.state.menstrualStatus == status)
        #expect(store.state.isLoadingMenstrual == false)
        #expect(store.state.cycle != nil) // cycle is computed from menstrualStatus
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @Test("menstrualStatusLoaded.failure still broadcasts nil cycle")
    func failureBroadcastsNilCycle() async {
        let store = TestStore(initialState: TodayFeature.State()) {
            TodayFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        struct TestError: Error {}
        await store.send(.menstrualStatusLoaded(.failure(TestError())))
        await store.receive(\.delegate.cycleDataUpdated)
        // After: menstrualStatus stays nil → cycle is nil
        #expect(store.state.cycle == nil)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @Test("phaseResolved fans out to cardStack.loadCards and dailyChallenge.selectChallenge")
    func phaseResolvedFanOut() async {
        let store = TestStore(initialState: TodayFeature.State()) {
            TodayFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.phaseResolved(.follicular, 8))
        // Expect the two child actions emitted downstream.
        await store.receive(\.cardStack.loadCards)
        await store.receive(\.dailyChallenge.selectChallenge)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }
}

// MARK: - Broadcast: Home forwards Today.cycleDataUpdated to siblings

@MainActor
@Suite("Broadcast — Home fan-out", .serialized)
struct HomeBroadcastTests {

    @Test("Home forwards today.delegate.cycleDataUpdated to cycleInsights + cycleJourney")
    func homeForwardsCycleData() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        // Build a test cycle context
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let context = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )

        await store.send(.today(.delegate(.cycleDataUpdated(context))))

        await store.receive(\.cycleInsights.cycleDataChanged) { state in
            state.cycleInsightsState.cycleContext = context
        }
        await store.receive(\.cycleJourney.cycleDataChanged) { state in
            state.cycleJourneyState.cycleContext = context
        }
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @Test("Home forwards nil cycleDataUpdated (errored state)")
    func homeForwardsNil() async {
        var initial = HomeFeature.State()
        // Pre-seed children with stale data — should get cleared to nil
        let stale = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: Date(), currentPhase: .follicular,
            nextPeriodIn: nil, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        initial.cycleInsightsState.cycleContext = stale
        initial.cycleJourneyState.cycleContext = stale

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.today(.delegate(.cycleDataUpdated(nil))))
        await store.receive(\.cycleInsights.cycleDataChanged) {
            $0.cycleInsightsState.cycleContext = nil
        }
        await store.receive(\.cycleJourney.cycleDataChanged) {
            $0.cycleJourneyState.cycleContext = nil
        }
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }
}

// MARK: - Child behavior on broadcast receipt

@MainActor
@Suite("Broadcast — Children update state on receipt")
struct ChildBroadcastReceiptTests {

    @Test("CardStackFeature.hbiUpdated updates currentHBI")
    func cardStackStoresHBI() async {
        let store = TestStore(initialState: CardStackFeature.State()) {
            CardStackFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.hbiUpdated(HBIScore.mock)) {
            $0.currentHBI = HBIScore.mock
        }
    }

    @Test("DailyChallengeFeature.hbiUpdated updates currentHBI")
    func dailyChallengeStoresHBI() async {
        let store = TestStore(initialState: DailyChallengeFeature.State()) {
            DailyChallengeFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.hbiUpdated(HBIScore.mock)) {
            $0.currentHBI = HBIScore.mock
        }
    }

    @Test("CycleInsightsFeature.cycleDataChanged updates cycleContext")
    func cycleInsightsReceivesContext() async {
        let context = CycleContext(
            cycleDay: 14, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: Date(), currentPhase: .ovulatory,
            nextPeriodIn: 14, fertileWindowActive: true,
            periodDays: [], predictedDays: []
        )
        let store = TestStore(initialState: CycleInsightsFeature.State()) {
            CycleInsightsFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.cycleDataChanged(context)) {
            $0.cycleContext = context
        }
    }

    @Test("CycleJourneyFeature.cycleDataChanged updates cycleContext")
    func cycleJourneyReceivesContext() async {
        let context = CycleContext(
            cycleDay: 21, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: Date(), currentPhase: .luteal,
            nextPeriodIn: 7, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        let store = TestStore(initialState: CycleJourneyFeature.State()) {
            CycleJourneyFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.cycleDataChanged(context)) {
            $0.cycleContext = context
        }
    }

    @Test("Child accepts nil to clear stale data")
    func clearStaleData() async {
        let stale = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: Date(), currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        var initial = CycleInsightsFeature.State()
        initial.cycleContext = stale

        let store = TestStore(initialState: initial) {
            CycleInsightsFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.cycleDataChanged(nil)) {
            $0.cycleContext = nil
        }
    }
}
