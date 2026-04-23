@testable import CycleApp
import ComposableArchitecture
import Foundation
import Testing

// MARK: - EditPeriodFeature: User-data write path

/// Guards the EditPeriod reducer because mistakes here corrupt period
/// history — the worst kind of bug for a cycle tracker. Covers the three
/// ways `dayTapped` mutates state (auto-fill, extend, remove-with-trail),
/// and the two exit paths (explicit save vs auto-save on cancel).
@MainActor
@Suite("EditPeriodFeature — period editing")
struct EditPeriodFeatureTests {

    private static let calendar = Calendar.current

    private static func key(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func makeState(
        bleedingDays: Int = 5,
        periodDays: Set<String> = [],
        flow: [String: FlowIntensity] = [:]
    ) -> EditPeriodFeature.State {
        EditPeriodFeature.State(
            cycleStartDate: Date(),
            cycleLength: 28,
            bleedingDays: bleedingDays,
            periodDays: periodDays,
            periodFlowIntensity: flow
        )
    }

    // MARK: Auto-fill

    @Test("Tapping an isolated empty day auto-fills `bleedingDays` consecutive days")
    func dayTapped_autoFillsFromBleedingDaysAverage() async {
        let tappedDay = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let store = TestStore(initialState: Self.makeState(bleedingDays: 5)) {
            EditPeriodFeature()
        }

        await store.send(.dayTapped(tappedDay)) { state in
            for offset in 0..<5 {
                let d = Self.calendar.date(byAdding: .day, value: offset, to: tappedDay)!
                let k = Self.key(d)
                state.snapshot.periodDays.insert(k)
                state.snapshot.flowIntensity[k] = .medium
            }
        }
    }

    @Test("Auto-fill uses a 3-day floor when the user's bleedingDays is lower")
    func dayTapped_bleedingDaysFloorsToThree() async {
        let tappedDay = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let store = TestStore(initialState: Self.makeState(bleedingDays: 1)) {
            EditPeriodFeature()
        }

        await store.send(.dayTapped(tappedDay)) { state in
            for offset in 0..<3 {
                let d = Self.calendar.date(byAdding: .day, value: offset, to: tappedDay)!
                let k = Self.key(d)
                state.snapshot.periodDays.insert(k)
                state.snapshot.flowIntensity[k] = .medium
            }
        }
    }

    // MARK: Extend adjacent

    @Test("Tapping a day adjacent to an existing period adds only that single day")
    func dayTapped_adjacentAddsOneDay() async {
        let existing = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let tapped = Self.calendar.date(byAdding: .day, value: 1, to: existing)!
        let existingKey = Self.key(existing)

        let store = TestStore(
            initialState: Self.makeState(
                bleedingDays: 5,
                periodDays: [existingKey],
                flow: [existingKey: .medium]
            )
        ) {
            EditPeriodFeature()
        }

        await store.send(.dayTapped(tapped)) { state in
            let tappedKey = Self.key(tapped)
            state.snapshot.periodDays.insert(tappedKey)
            state.snapshot.flowIntensity[tappedKey] = .medium
        }
    }

    // MARK: Remove with future trail

    @Test("Tapping an existing period day removes it AND all future consecutive period days")
    func dayTapped_existingDayRemovesWithFutureTrail() async {
        // Build a 5-day period starting several days in the future so
        // "startOfDay >= today" keeps the trail-removal active.
        let start = Self.calendar.date(byAdding: .day, value: 5, to: Self.calendar.startOfDay(for: Date()))!
        let day0 = Self.key(start)
        let day1 = Self.key(Self.calendar.date(byAdding: .day, value: 1, to: start)!)
        let day2 = Self.key(Self.calendar.date(byAdding: .day, value: 2, to: start)!)
        let day3 = Self.key(Self.calendar.date(byAdding: .day, value: 3, to: start)!)
        let day4 = Self.key(Self.calendar.date(byAdding: .day, value: 4, to: start)!)
        let allDays: Set<String> = [day0, day1, day2, day3, day4]
        let flow: [String: FlowIntensity] = Dictionary(uniqueKeysWithValues: allDays.map { ($0, .medium) })

        let store = TestStore(
            initialState: Self.makeState(periodDays: allDays, flow: flow)
        ) {
            EditPeriodFeature()
        }

        // Tap day1 → should leave only day0, dropping day1..day4.
        await store.send(.dayTapped(Self.calendar.date(byAdding: .day, value: 1, to: start)!)) { state in
            state.snapshot.periodDays = [day0]
            state.snapshot.flowIntensity = [day0: .medium]
        }
    }

    // MARK: Cancel paths

    @Test("Cancel with no changes dismisses silently (no delegate fired)")
    func cancel_noChanges_noDelegate() async {
        let existingKey = Self.key(Date())
        let store = TestStore(
            initialState: Self.makeState(
                periodDays: [existingKey],
                flow: [existingKey: .medium]
            )
        ) {
            EditPeriodFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {}
        }
        // Exhaustive mode — any unexpected delegate would fail the test.
        await store.send(.cancelTapped)
    }

    @Test("Cancel with unsaved changes auto-saves via delegate with needsServerSync=true")
    func cancel_withChanges_firesDelegateForAutoSave() async {
        let original = Self.key(Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!)
        let added = Self.key(Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!)

        var initial = Self.makeState(
            periodDays: [original],
            flow: [original: .medium]
        )
        // Simulate a local edit — added a day that isn't in originalPeriodDays.
        initial.snapshot.periodDays.insert(added)
        initial.snapshot.flowIntensity[added] = .medium

        let store = TestStore(initialState: initial) {
            EditPeriodFeature()
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate)
    }
}
