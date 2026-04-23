import ComposableArchitecture
import SwiftUI

// MARK: - EditPeriodFeature

@Reducer
public struct EditPeriodFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var initialMonth: Date

        /// Unified cycle-derived calendar data — single source of truth.
        /// `periodDays` / `periodFlowIntensity` / `predictedPeriodDays` are
        /// computed passthroughs into this.
        public var snapshot: CycleSnapshot = .empty

        public var periodDays: Set<String> {
            get { snapshot.periodDays }
            set { snapshot.periodDays = newValue }
        }
        public var periodFlowIntensity: [String: FlowIntensity] {
            get { snapshot.flowIntensity }
            set { snapshot.flowIntensity = newValue }
        }
        /// Predicted period days from server (read-only, shown with dashed style)
        public var predictedPeriodDays: Set<String> {
            get { snapshot.predictedDays }
            set { snapshot.predictedDays = newValue }
        }

        public var selectedPeriodDay: String?
        public var isUpdatingPredictions: Bool = false
        public var predictionsDone: Bool = false
        public var originalPeriodDays: Set<String> = []
        public var originalFlowIntensity: [String: FlowIntensity] = [:]

        public var hasChanges: Bool {
            periodDays != originalPeriodDays || periodFlowIntensity != originalFlowIntensity
        }

        // Read-only context from parent
        public var cycleStartDate: Date
        public var cycleLength: Int
        public var bleedingDays: Int

        public init(
            cycleStartDate: Date,
            cycleLength: Int,
            bleedingDays: Int,
            periodDays: Set<String> = [],
            periodFlowIntensity: [String: FlowIntensity] = [:],
            predictedPeriodDays: Set<String> = [],
            focusDate: Date? = nil
        ) {
            let target = focusDate ?? Date()
            self.initialMonth = Calendar.current.startOfMonth(for: target)
            self.snapshot = CycleSnapshot(
                periodDays: periodDays,
                predictedDays: predictedPeriodDays,
                flowIntensity: periodFlowIntensity
            )
            self.originalPeriodDays = periodDays
            self.originalFlowIntensity = periodFlowIntensity
            self.selectedPeriodDay = nil
            self.cycleStartDate = cycleStartDate
            self.cycleLength = cycleLength
            self.bleedingDays = bleedingDays
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case appeared
        case calendarLoaded(Result<MenstrualCalendarResponse, Error>)
        case dayTapped(Date)
        case saveTapped
        case saveDone(
            periodDays: Set<String>,
            periodFlowIntensity: [String: FlowIntensity]
        )
        case predictionsUpdated
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            /// Period data changed. `needsServerSync` = true when dismissed without explicit save.
            case didSavePeriodData(
                periodDays: Set<String>,
                originalPeriodDays: Set<String>,
                periodFlowIntensity: [String: FlowIntensity],
                bleedingDays: Int,
                needsServerSync: Bool
            )
            /// Fired after predictions are regenerated and calendar reloaded.
            case didFinishPredictions(
                periodDays: Set<String>,
                predictedPeriodDays: Set<String>,
                periodFlowIntensity: [String: FlowIntensity]
            )
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .appeared:
                // Load saved period days from backend calendar
                let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                let end = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
                return .run { [menstrualLocal] send in
                    let result = await Result {
                        try await menstrualLocal.getCalendar(start, end)
                    }
                    await send(.calendarLoaded(result))
                }

            case .calendarLoaded(.success(let response)):
                var serverDays: Set<String> = []
                var predicted: Set<String> = []
                let todayKey = Self.dateKey(Calendar.current.startOfDay(for: Date()))
                for entry in response.entries {
                    let localDay = Self.localDate(from: entry.date)
                    let key = Self.dateKey(localDay)
                    if entry.type == "period" {
                        serverDays.insert(key)
                        // Future bleeding days from current cycle → show as predicted
                        if key > todayKey {
                            predicted.insert(key)
                        }
                    } else if entry.type == "predicted_period" {
                        predicted.insert(key)
                    }
                }
                // Always use server as source of truth (even if empty)
                state.snapshot.periodDays = serverDays
                state.originalPeriodDays = serverDays
                state.snapshot.predictedDays = predicted
                print(
                    "[EditPeriod] calendarLoaded: periodDays=\(serverDays.sorted()), predictedDays=\(predicted.sorted())"
                )
                return .none

            case .calendarLoaded(.failure):
                return .none

            case .dayTapped(let date):
                let cal = Calendar.current
                let key = Self.dateKey(date)
                if state.snapshot.periodDays.contains(key) {
                    let today = cal.startOfDay(for: Date())
                    // Remove this day + all future period days after it
                    state.snapshot.periodDays.remove(key)
                    state.snapshot.flowIntensity.removeValue(forKey: key)
                    for i in 1...30 {
                        guard let d = cal.date(byAdding: .day, value: i, to: date),
                            cal.startOfDay(for: d) >= today
                        else { continue }
                        let k = Self.dateKey(d)
                        if state.snapshot.periodDays.contains(k) {
                            state.snapshot.periodDays.remove(k)
                            state.snapshot.flowIntensity.removeValue(forKey: k)
                        } else {
                            break
                        }
                    }
                } else {
                    // Check if tapped day is adjacent to existing period days
                    let isAdjacent = (-1...1).contains(where: { offset in
                        guard offset != 0,
                            let neighbor = cal.date(byAdding: .day, value: offset, to: date)
                        else { return false }
                        return state.snapshot.periodDays.contains(Self.dateKey(neighbor))
                    })

                    if isAdjacent {
                        state.snapshot.periodDays.insert(key)
                        state.snapshot.flowIntensity[key] = .medium
                    } else {
                        // Auto-fill using user's average bleeding days
                        let fillCount = max(state.bleedingDays, 3)
                        for i in 0..<fillCount {
                            guard let d = cal.date(byAdding: .day, value: i, to: date)
                            else { break }
                            let k = Self.dateKey(d)
                            state.snapshot.periodDays.insert(k)
                            state.snapshot.flowIntensity[k] = .medium
                        }
                    }
                }
                return .none

            case .saveTapped:
                state.isUpdatingPredictions = true
                let periodDays = state.periodDays
                let flowIntensity = state.periodFlowIntensity
                let originalPeriodDays = state.originalPeriodDays
                let periodGroups = Self.groupConsecutivePeriods(periodDays)
                let removedDays = originalPeriodDays.subtracting(periodDays)
                return .run { [menstrualLocal] send in
                    // Phase 1: Save period data locally
                    if !removedDays.isEmpty {
                        let datesToRemove = removedDays.compactMap { CalendarFeature.parseDate($0) }
                        try? await menstrualLocal.removePeriodDays(datesToRemove)
                    }
                    for group in periodGroups {
                        try? await menstrualLocal.confirmPeriod(
                            group.startDate, group.dayCount, nil, true
                        )
                    }

                    // Immediately notify parent
                    await send(
                        .delegate(.didSavePeriodData(
                            periodDays: periodDays,
                            originalPeriodDays: originalPeriodDays,
                            periodFlowIntensity: flowIntensity,
                            bleedingDays: periodGroups.first?.dayCount ?? 5,
                            needsServerSync: false
                        ))
                    )

                    // Phase 2: Show "Improving predictions" banner
                    await send(
                        .saveDone(
                            periodDays: periodDays,
                            periodFlowIntensity: flowIntensity
                        ),
                        animation: .easeInOut(duration: 0.3)
                    )

                    // Phase 3: Regenerate predictions + reload calendar
                    try? await menstrualLocal.generatePrediction()
                    let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                    let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                    if let response = try? await menstrualLocal.getCalendar(start, end) {
                        await send(.calendarLoaded(.success(response)), animation: .easeInOut(duration: 0.4))
                    }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.predictionsUpdated)
                }

            case .saveDone(let days, let flow):
                state.originalPeriodDays = days
                state.originalFlowIntensity = flow
                return .none

            case .predictionsUpdated:
                state.isUpdatingPredictions = false
                state.predictionsDone = true
                let freshPeriodDays = state.periodDays
                let predictedDays = state.predictedPeriodDays
                let flowIntensity = state.periodFlowIntensity
                return .run { send in
                    // Show checkmark for 1s then dismiss
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(
                        .delegate(
                            .didFinishPredictions(
                                periodDays: freshPeriodDays,
                                predictedPeriodDays: predictedDays,
                                periodFlowIntensity: flowIntensity
                            )
                        )
                    )
                }

            case .cancelTapped:
                // Auto-save: dismiss immediately, parent handles background sync
                if state.hasChanges {
                    let periodDays = state.periodDays
                    let originalPeriodDays = state.originalPeriodDays
                    let flowIntensity = state.periodFlowIntensity
                    let bleedingDays = state.bleedingDays
                    return .send(
                        .delegate(.didSavePeriodData(
                            periodDays: periodDays,
                            originalPeriodDays: originalPeriodDays,
                            periodFlowIntensity: flowIntensity,
                            bleedingDays: bleedingDays,
                            needsServerSync: true
                        ))
                    )
                }
                return .run { _ in await dismiss() }

            case .binding, .delegate:
                return .none
            }
        }
    }

    static func dateKey(_ date: Date) -> String {
        DateFormatter.dayKey.string(from: date)
    }

    /// Converts a server date to local midnight for the same calendar day.
    /// Adding 12h before extracting UTC components handles non-UTC server timezones.
    static func localDate(from serverDate: Date) -> Date {
        let noon = serverDate.addingTimeInterval(12 * 3600)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: noon)
        return Calendar.current.date(from: comps) ?? serverDate
    }

    /// Groups a flat set of period day strings into consecutive streaks.
    /// Each streak becomes a separate period with its own start date and day count.
    struct PeriodGroup: Sendable {
        let startDate: Date
        let dayCount: Int
    }

    static func groupConsecutivePeriods(_ dayKeys: Set<String>) -> [PeriodGroup] {
        let cal = Calendar.current
        let fmt = DateFormatter.dayKey
        // dateKey() uses local timezone, so parse back with local timezone
        let dates =
            dayKeys
            .compactMap { fmt.date(from: $0) }
            .map { cal.startOfDay(for: $0) }
            .sorted()
        guard let first = dates.first else { return [] }

        var groups: [PeriodGroup] = []
        var streakStart = first
        var streakCount = 1

        for i in 1..<dates.count {
            let diff = cal.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            if diff == 1 {
                streakCount += 1
            } else {
                groups.append(PeriodGroup(startDate: streakStart, dayCount: streakCount))
                streakStart = dates[i]
                streakCount = 1
            }
        }
        groups.append(PeriodGroup(startDate: streakStart, dayCount: streakCount))
        return groups
    }
}
