import ComposableArchitecture
import SwiftUI

// MARK: - CalendarFeature

@Reducer
public struct CalendarFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var menstrualStatus: MenstrualStatusResponse?
        public var displayedMonth: Date
        public var selectedDate: Date
        public var loggedDays: [String: DayLog] = [:]
        public var symptomSearchText: String = ""
        public var isShowingSymptomSheet: Bool = false
        public var isSavingSymptoms: Bool = false
        public var symptomsSaved: Bool = false
        public var showAriaPrompt: Bool = false
        public var ariaPromptMessage: String = ""
        public var isLoadingCalendar: Bool = false
        /// True after pre-loading calendar data at app start
        public var hasPreloaded: Bool = false
        public var calendarEntries: [MenstrualCalendarEntry] = []

        // Effective cycle params (may be edited by user)
        public var cycleStartDate: Date
        public var cycleLength: Int
        public var bleedingDays: Int

        // User-marked period days (keys: "yyyy-MM-dd") — confirmed + predicted from server
        public var periodDays: Set<String> = []
        // Server-predicted period days (subset of periodDays) — for dashed/lighter styling
        public var predictedPeriodDays: Set<String> = []
        // Flow intensity per period day (keys: "yyyy-MM-dd")
        public var periodFlowIntensity: [String: FlowIntensity] = [:]
        // Fertile days with their level (keys: "yyyy-MM-dd")
        public var fertileDays: [String: FertilityLevel] = [:]
        // Ovulation days (keys: "yyyy-MM-dd")
        public var ovulationDays: Set<String> = []

        // Inline edit period mode
        public var isEditingPeriod: Bool = false
        public var editPeriodDays: Set<String> = []
        public var editOriginalPeriodDays: Set<String> = []
        public var editFlowIntensity: [String: FlowIntensity] = [:]
        public var isUpdatingPredictions: Bool = false
        public var predictionsDone: Bool = false
        /// Bumped after calendar reload to trigger refresh animation
        public var calendarRefreshTick: Int = 0

        public var hasEditPeriodChanges: Bool {
            editPeriodDays != editOriginalPeriodDays
        }

        public struct DayLog: Equatable, Sendable {
            public var symptoms: [String] = []
            public var notes: String = ""
        }

        public init(
            menstrualStatus: MenstrualStatusResponse? = nil,
            periodDays: Set<String> = [],
            predictedPeriodDays: Set<String> = [],
            fertileDays: [String: FertilityLevel] = [:],
            ovulationDays: Set<String> = []
        ) {
            self.menstrualStatus = menstrualStatus
            let today = Calendar.current.startOfDay(for: Date())
            self.selectedDate = today
            var comps = Calendar.current.dateComponents([.year, .month], from: today)
            comps.day = 1
            self.displayedMonth = Calendar.current.date(from: comps) ?? today

            let hasCycleData = menstrualStatus?.hasCycleData ?? false
            let localCal = Calendar.current
            if hasCycleData, let serverStart = menstrualStatus?.currentCycle.startDate {
                let startDate = CalendarFeature.localDate(from: serverStart)
                self.cycleStartDate = localCal.startOfDay(for: startDate)
            } else {
                self.cycleStartDate = localCal.date(byAdding: .year, value: -100, to: today) ?? today
            }
            self.cycleLength = menstrualStatus?.profile.avgCycleLength ?? 28
            self.bleedingDays = menstrualStatus?.currentCycle.bleedingDays ?? 5

            // Pre-populate with already-loaded data for instant display
            self.periodDays = periodDays
            self.predictedPeriodDays = predictedPeriodDays
            self.fertileDays = fertileDays
            self.ovulationDays = ovulationDays
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case dismissTapped
        case daySelected(Date)
        case logSymptomsTapped
        case symptomToggled(SymptomType)
        case saveSymptomsTapped
        case saveSymptomsDone
        case symptomSheetDismissed
        case cycleLengthChanged(Int)
        case editPeriodToggled
        case editPeriodDayTapped(Date)
        case editPeriodSaveTapped
        case editPeriodSaveDone(periodDays: Set<String>, periodFlowIntensity: [String: FlowIntensity])
        case editPeriodPredictionsUpdated
        case editPeriodCalendarReloaded(Result<MenstrualCalendarResponse, Error>)
        case ariaPromptTalkTapped
        case ariaPromptDismissed
        case loadCalendar
        case calendarLoaded(Result<MenstrualCalendarResponse, Error>)
        case symptomsLoaded(Result<[MenstrualSymptomResponse], Error>)
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case didDismiss(periodDays: Set<String>)
            case openAriaChat(context: String)
            /// Period data was saved (API already done) — parent should reload
            case periodDataChanged
            /// Period data changed locally — parent must save to server + reload
            case periodDataNeedsSync(
                periodDays: Set<String>,
                originalPeriodDays: Set<String>,
                periodFlowIntensity: [String: FlowIntensity],
                bleedingDays: Int
            )
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .dismissTapped:
                let periodDays = state.periodDays
                return .send(.delegate(.didDismiss(periodDays: periodDays)))

            case .daySelected(let date):
                let day = Calendar.current.startOfDay(for: date)
                state.selectedDate = day
                if day <= Calendar.current.startOfDay(for: Date()) {
                    state.isShowingSymptomSheet = true
                }
                return .run { [menstrualLocal] send in
                    let result = await Result {
                        try await menstrualLocal.getSymptoms(day)
                    }
                    await send(.symptomsLoaded(result))
                }

            case .logSymptomsTapped:
                state.selectedDate = Calendar.current.startOfDay(for: Date())
                state.isShowingSymptomSheet = true
                return .none

            case .symptomToggled(let symptom):
                let key = CalendarFeature.dateKey(state.selectedDate)
                var log = state.loggedDays[key] ?? State.DayLog()
                if log.symptoms.contains(symptom.rawValue) {
                    log.symptoms.removeAll { $0 == symptom.rawValue }
                } else {
                    log.symptoms.append(symptom.rawValue)
                }
                state.loggedDays[key] = log
                return .none

            case .saveSymptomsTapped:
                state.isSavingSymptoms = true
                state.symptomsSaved = false
                let key = CalendarFeature.dateKey(state.selectedDate)
                let symptoms = state.loggedDays[key]?.symptoms ?? []
                let date = state.selectedDate
                return .run { [menstrualLocal] send in
                    for symptom in symptoms {
                        try? await menstrualLocal.logSymptom(date, symptom, 3, nil)
                    }
                    await send(.saveSymptomsDone, animation: .easeInOut(duration: 0.3))
                }

            case .saveSymptomsDone:
                state.isSavingSymptoms = false
                state.symptomsSaved = true
                let key = CalendarFeature.dateKey(state.selectedDate)
                let symptoms = state.loggedDays[key]?.symptoms ?? []
                let phase = CalendarFeature.phaseInfo(
                    for: state.selectedDate,
                    cycleStartDate: state.cycleStartDate,
                    cycleLength: state.cycleLength,
                    bleedingDays: state.bleedingDays
                )?.phase
                state.ariaPromptMessage = Self.ariaMessage(symptoms: symptoms, phase: phase)
                return .run { send in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await send(.symptomSheetDismissed, animation: .spring(response: 0.4, dampingFraction: 0.85))
                }

            case .symptomSheetDismissed:
                let wasSaved = state.symptomsSaved
                state.isShowingSymptomSheet = false
                state.symptomsSaved = false
                state.symptomSearchText = ""
                if wasSaved && !state.ariaPromptMessage.isEmpty {
                    // Delay to let symptom sheet fully dismiss before presenting Aria sheet
                    return .run { send in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await send(.binding(.set(\.showAriaPrompt, true)), animation: .spring(response: 0.4, dampingFraction: 0.85))
                    }
                }
                return .none

            case .ariaPromptTalkTapped:
                state.showAriaPrompt = false
                let key = CalendarFeature.dateKey(state.selectedDate)
                let symptoms = state.loggedDays[key]?.symptoms ?? []
                let context = symptoms.joined(separator: ", ")
                return .send(.delegate(.openAriaChat(context: context)))

            case .ariaPromptDismissed:
                state.showAriaPrompt = false
                return .none

            case .loadCalendar:
                state.isLoadingCalendar = true
                let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                return .run { [menstrualLocal] send in
                    let result = await Result {
                        try await menstrualLocal.getCalendar(start, end)
                    }
                    await send(.calendarLoaded(result), animation: .easeInOut(duration: 0.35))
                }

            case .calendarLoaded(.success(let response)):
                state.isLoadingCalendar = false
                state.calendarEntries = response.entries
                Self.parseCalendarEntries(response.entries, into: &state)
                return .none

            case .calendarLoaded(.failure):
                state.isLoadingCalendar = false
                return .none

            case .symptomsLoaded(.success(let symptoms)):
                let key = CalendarFeature.dateKey(state.selectedDate)
                var log = state.loggedDays[key] ?? State.DayLog()
                log.symptoms = symptoms.map(\.symptomType)
                state.loggedDays[key] = log
                return .none

            case .symptomsLoaded(.failure):
                return .none

            case .cycleLengthChanged(let length):
                state.cycleLength = length
                return .none

            case .editPeriodToggled:
                if state.isEditingPeriod {
                    // Cancel — discard changes, restore original state
                    state.isEditingPeriod = false
                    state.editPeriodDays = state.editOriginalPeriodDays
                    return .none
                } else {
                    let confirmedDays = state.periodDays.subtracting(state.predictedPeriodDays)
                    state.isEditingPeriod = true
                    state.editPeriodDays = confirmedDays
                    state.editOriginalPeriodDays = confirmedDays
                    state.editFlowIntensity = state.periodFlowIntensity
                    state.isUpdatingPredictions = false
                    state.predictionsDone = false
                    return .none
                }

            case .editPeriodDayTapped(let date):
                let cal = Calendar.current
                let key = CalendarFeature.dateKey(date)
                if state.editPeriodDays.contains(key) {
                    // Find the first day of this consecutive block
                    var firstDate = date
                    for i in 1...30 {
                        guard let d = cal.date(byAdding: .day, value: -i, to: date) else { break }
                        guard state.editPeriodDays.contains(CalendarFeature.dateKey(d)) else { break }
                        firstDate = d
                    }

                    if cal.isDate(date, inSameDayAs: firstDate) {
                        // First day — remove entire block
                        state.editPeriodDays.remove(key)
                        state.editFlowIntensity.removeValue(forKey: key)
                        for i in 1...30 {
                            guard let d = cal.date(byAdding: .day, value: i, to: date) else { break }
                            let k = CalendarFeature.dateKey(d)
                            guard state.editPeriodDays.contains(k) else { break }
                            state.editPeriodDays.remove(k)
                            state.editFlowIntensity.removeValue(forKey: k)
                        }
                    } else {
                        // Any other day — remove just that one day
                        state.editPeriodDays.remove(key)
                        state.editFlowIntensity.removeValue(forKey: key)
                    }
                } else {
                    let isAdjacent = (-1...1).contains(where: { offset in
                        guard offset != 0,
                              let neighbor = cal.date(byAdding: .day, value: offset, to: date)
                        else { return false }
                        return state.editPeriodDays.contains(CalendarFeature.dateKey(neighbor))
                    })

                    if isAdjacent {
                        // Adjacent to existing block — add single day
                        state.editPeriodDays.insert(key)
                        state.editFlowIntensity[key] = .medium
                    } else {
                        // Not adjacent — start new block with bleedingDays fill
                        let fillCount = max(state.bleedingDays, 3)
                        for i in 0..<fillCount {
                            guard let d = cal.date(byAdding: .day, value: i, to: date) else { break }
                            let k = CalendarFeature.dateKey(d)
                            state.editPeriodDays.insert(k)
                            state.editFlowIntensity[k] = .medium
                        }
                    }
                }
                return .none

            case .editPeriodSaveTapped:
                state.isUpdatingPredictions = true
                let periodDays = state.editPeriodDays
                let flowIntensity = state.editFlowIntensity
                let originalPeriodDays = state.editOriginalPeriodDays
                let periodGroups = EditPeriodFeature.groupConsecutivePeriods(periodDays)
                let removedDays = originalPeriodDays.subtracting(periodDays)

                state.periodDays = periodDays
                state.periodFlowIntensity = flowIntensity
                if periodDays.isEmpty {
                    let today = Calendar.current.startOfDay(for: Date())
                    state.cycleStartDate =
                        state.menstrualStatus.map {
                            Calendar.current.startOfDay(
                                for: CalendarFeature.localDate(from: $0.currentCycle.startDate)
                            )
                        } ?? Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today
                    state.bleedingDays = state.menstrualStatus?.currentCycle.bleedingDays ?? 5
                } else {
                    CalendarFeature.recomputeCycle(from: &state)
                }

                return .run { [menstrualLocal] send in
                    if !removedDays.isEmpty {
                        let datesToRemove = removedDays.compactMap { CalendarFeature.parseDate($0) }
                        try? await menstrualLocal.removePeriodDays(datesToRemove)
                    }
                    for group in periodGroups {
                        try? await menstrualLocal.confirmPeriod(
                            group.startDate, group.dayCount, nil, true
                        )
                    }

                    await send(
                        .editPeriodSaveDone(
                            periodDays: periodDays,
                            periodFlowIntensity: flowIntensity
                        ),
                        animation: .easeInOut(duration: 0.3)
                    )

                    if !periodGroups.isEmpty {
                        try? await menstrualLocal.generatePrediction()
                    }
                    let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                    let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                    let calResult = await Result {
                        try await menstrualLocal.getCalendar(start, end)
                    }
                    await send(.editPeriodCalendarReloaded(calResult), animation: .easeInOut(duration: 0.4))

                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.editPeriodPredictionsUpdated)
                }

            case .editPeriodSaveDone(let days, let flow):
                state.editOriginalPeriodDays = days
                state.editFlowIntensity = flow
                return .none

            case .editPeriodCalendarReloaded(.success(let response)):
                state.calendarEntries = response.entries
                Self.parseCalendarEntries(response.entries, into: &state)
                state.calendarRefreshTick += 1
                state.editPeriodDays = state.periodDays.subtracting(state.predictedPeriodDays)
                state.editOriginalPeriodDays = state.editPeriodDays
                return .none

            case .editPeriodCalendarReloaded(.failure):
                return .none

            case .editPeriodPredictionsUpdated:
                state.isUpdatingPredictions = false
                state.predictionsDone = true
                state.isEditingPeriod = false
                return .run { send in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.delegate(.periodDataChanged))
                }

            case .binding, .delegate:
                return .none
            }
        }
    }

    // MARK: - Helpers

    private static let dateKeyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    static func dateKey(_ date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    /// Parse a "yyyy-MM-dd" key back to a Date.
    static func parseDate(_ key: String) -> Date? {
        dateKeyFormatter.date(from: key)
    }

    /// Converts a server date to local midnight for the same calendar day.
    public static func localDate(from serverDate: Date) -> Date {
        let noon = serverDate.addingTimeInterval(12 * 3600)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: noon)
        return Calendar.current.date(from: comps) ?? serverDate
    }

    /// Converts a local midnight date to UTC midnight for the same calendar day.
    public static func utcDate(from localDate: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        return utcCal.date(from: comps) ?? localDate
    }

    /// Parses calendar entries from the server into state period/fertile/ovulation sets.
    static func parseCalendarEntries(_ entries: [MenstrualCalendarEntry], into state: inout State) {
        var serverPeriodDays: Set<String> = []
        var serverPredictedDays: Set<String> = []
        var serverFertileDays: [String: FertilityLevel] = [:]
        var serverOvulationDays: Set<String> = []
        for entry in entries {
            let localDay = Self.localDate(from: entry.date)
            let key = Self.dateKey(localDay)
            switch entry.type {
            case "period":
                serverPeriodDays.insert(key)
            case "predicted_period":
                serverPeriodDays.insert(key)
                serverPredictedDays.insert(key)
            case "fertile":
                if let levelStr = entry.fertilityLevel,
                   let level = FertilityLevel(rawValue: levelStr) {
                    serverFertileDays[key] = level
                }
            case "ovulation":
                serverOvulationDays.insert(key)
            default: break
            }
        }
        // Synthesize predicted days from menstrual status when late
        if serverPredictedDays.isEmpty,
           let pred = state.menstrualStatus?.nextPrediction,
           pred.isLate
        {
            let predDate = CalendarFeature.localDate(from: pred.predictedDate)
            let bleed = state.bleedingDays
            let cal = Calendar.current
            for i in 0..<bleed {
                if let d = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: predDate)) {
                    let key = CalendarFeature.dateKey(d)
                    serverPeriodDays.insert(key)
                    serverPredictedDays.insert(key)
                }
            }
        }

        state.periodDays = serverPeriodDays
        state.predictedPeriodDays = serverPredictedDays
        state.fertileDays = serverFertileDays
        state.ovulationDays = serverOvulationDays
    }

    static func ariaMessage(symptoms: [String], phase: CyclePhase?) -> String {
        let hasMood = symptoms.contains(where: {
            ["anxious", "sad", "irritable", "moodSwings", "overwhelmed", "lonely"].contains($0)
        })
        let hasPain = symptoms.contains(where: {
            ["cramps", "headache", "backPain", "breastTenderness", "bodyAches"].contains($0)
        })
        let hasLowEnergy = symptoms.contains(where: {
            ["lowEnergy", "fatigue", "insomnia", "restlessSleep"].contains($0)
        })

        switch (hasMood, hasPain, hasLowEnergy, phase) {
        case (true, _, _, .menstrual):
            return
                "I noticed you're feeling emotionally heavy today. During your period, hormone shifts can amplify everything. Want to talk through it? I'm here."
        case (true, _, _, .luteal):
            return
                "The luteal phase can bring waves of emotion that feel bigger than usual. You're not imagining it — and you don't have to carry it alone."
        case (true, _, _, _):
            return
                "I see what you're feeling today. Sometimes just putting it into words helps. Want to explore this together?"
        case (_, true, _, .menstrual):
            return
                "Your body is working hard right now. I have some gentle relief ideas that might help — want me to walk you through them?"
        case (_, true, _, _):
            return
                "Pain can be draining in ways that go beyond the physical. I'd love to help you find some comfort today."
        case (_, _, true, _):
            return
                "Low energy days deserve gentleness, not guilt. I can suggest a few things that might help you recharge — shall we chat?"
        default:
            return
                "Thank you for checking in with yourself today. Tracking these patterns helps me understand you better. Want to talk about how you're feeling?"
        }
    }

    private static func recomputeCycle(from state: inout State) {
        guard !state.periodDays.isEmpty else { return }
        let groups = EditPeriodFeature.groupConsecutivePeriods(state.periodDays)
        guard !groups.isEmpty else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let pastGroups = groups.filter { $0.startDate <= today }
        guard let best = pastGroups.last ?? groups.first else { return }

        state.cycleStartDate = best.startDate
        state.bleedingDays = best.dayCount
    }

    // MARK: - Phase Calculation

    public static func phaseInfo(
        for date: Date,
        cycleStartDate: Date,
        cycleLength: Int,
        bleedingDays: Int
    ) -> (phase: CyclePhase, cycleDay: Int, isPredicted: Bool)? {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: cycleStartDate)
        let diff = cal.dateComponents([.day], from: start, to: d).day ?? 0
        guard diff >= 0 else { return nil }
        let cycleIndex = diff / cycleLength
        guard cycleIndex <= 12 else { return nil }
        let dayInCycle = diff % cycleLength + 1
        let ovDay = cycleLength - 14
        let phase: CyclePhase
        switch dayInCycle {
        case 1...bleedingDays: phase = .menstrual
        case (bleedingDays + 1)...(max(bleedingDays + 1, ovDay - 2)): phase = .follicular
        case (ovDay - 1)...(ovDay + 1): phase = .ovulatory
        default: phase = .luteal
        }
        return (phase, dayInCycle, cycleIndex > 0)
    }
}
