import ComposableArchitecture
import SwiftUI

// MARK: - CalendarFeature

@Reducer
public struct CalendarFeature: Sendable {
    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case dismissTapped
        case daySelected(Date)
        case logSymptomsTapped
        /// Fired by `SymptomLoggingSheet.task` once it has
        /// applied `pendingFocusedSymptomRaw` to its tab state,
        /// so the next sheet opens fresh.
        case pendingFocusedSymptomCleared
        case symptomToggled(SymptomType)
        /// Long-press → user picks Mild (1), Moderate (3), or
        /// Severe (5) for an already-selected symptom. Adds
        /// the symptom to the day if it isn't there yet.
        case symptomSeverityChanged(SymptomType, Int)
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
            /// Symptom log was saved (add / remove / both). Parent
            /// surfaces that fire `PatternDetector` (BodyPatterns)
            /// reload off this so the screen reflects fresh data
            /// the moment the symptom screen dismisses.
            case symptomsSaved
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

            case .pendingFocusedSymptomCleared:
                state.pendingFocusedSymptomRaw = nil
                return .none

            case .symptomToggled(let symptom):
                let key = CalendarFeature.dateKey(state.selectedDate)
                var log = state.loggedDays[key] ?? State.DayLog()
                let raw = symptom.rawValue
                if log.symptoms.contains(raw) {
                    log.symptoms.removeAll { $0 == raw }
                    log.severities.removeValue(forKey: raw)
                } else {
                    log.symptoms.append(raw)
                    log.severities[raw] = 3
                }
                state.loggedDays[key] = log
                return .none

            case .symptomSeverityChanged(let symptom, let severity):
                let key = CalendarFeature.dateKey(state.selectedDate)
                var log = state.loggedDays[key] ?? State.DayLog()
                let raw = symptom.rawValue
                if !log.symptoms.contains(raw) {
                    log.symptoms.append(raw)
                }
                log.severities[raw] = max(1, min(5, severity))
                state.loggedDays[key] = log
                return .none

            case .saveSymptomsTapped:
                state.isSavingSymptoms = true
                state.symptomsSaved = false
                let key = CalendarFeature.dateKey(state.selectedDate)
                let selected = Set(state.loggedDays[key]?.symptoms ?? [])
                let severities = state.loggedDays[key]?.severities ?? [:]
                let date = state.selectedDate
                return .run { [menstrualLocal] send in
                    // Diff against what's currently in the DB so we
                    // both LOG newly selected symptoms, REMOVE
                    // un-toggled ones, and UPDATE severity changes
                    // on symptoms that stayed selected.
                    //
                    // Severity update path is "remove + re-add" —
                    // the local client doesn't expose an in-place
                    // severity write, and re-adding is cheap on
                    // SwiftData (sub-millisecond).
                    //
                    // Run DB work in parallel with a 700ms minimum
                    // window so the user sees the pulsing-dot
                    // phase on `AppDoneButton`. Without this
                    // floor (writes finish <100ms) the button
                    // skips straight to success and the feedback
                    // feels unearned.
                    async let savingTask: Void = {
                        let existing = (try? await menstrualLocal.getSymptoms(date)) ?? []
                        let existingTypes = Set(existing.map(\.symptomType))
                        let existingSeverity = Dictionary(
                            uniqueKeysWithValues: existing.map { ($0.symptomType, $0.severity) }
                        )

                        let toAdd = selected.subtracting(existingTypes)
                        let toRemove = existingTypes.subtracting(selected)
                        let toUpdate = selected.intersection(existingTypes).filter { raw in
                            existingSeverity[raw] != (severities[raw] ?? 3)
                        }

                        for symptom in toAdd {
                            let severity = severities[symptom] ?? 3
                            try? await menstrualLocal.logSymptom(date, symptom, severity, nil)
                        }
                        for symptom in toRemove {
                            try? await menstrualLocal.removeSymptom(date, symptom)
                        }
                        for symptom in toUpdate {
                            try? await menstrualLocal.removeSymptom(date, symptom)
                            let severity = severities[symptom] ?? 3
                            try? await menstrualLocal.logSymptom(date, symptom, severity, nil)
                        }
                    }()
                    async let minWait: Void = {
                        try? await Task.sleep(nanoseconds: 700_000_000)
                    }()

                    _ = await savingTask
                    _ = await minWait

                    await send(.saveSymptomsDone, animation: .easeInOut(duration: 0.45))
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
                return .merge(
                    // Fire-and-forget delegate so parent surfaces
                    // (BodyPatterns) can re-run PatternDetector
                    // against the fresh DB the moment the user
                    // dismisses the symptom screen.
                    .send(.delegate(.symptomsSaved)),
                    .run { send in
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        await send(.symptomSheetDismissed, animation: .appBalanced)
                    }
                )

            case .symptomSheetDismissed:
                let wasSaved = state.symptomsSaved
                state.isShowingSymptomSheet = false
                state.symptomsSaved = false
                state.symptomSearchText = ""
                if wasSaved && !state.ariaPromptMessage.isEmpty {
                    // Delay to let symptom sheet fully dismiss before presenting Aria sheet
                    return .run { send in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await send(.binding(.set(\.showAriaPrompt, true)), animation: .appBalanced)
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
                // Mirror the effective period length so the phase-pill
                // renderer draws bands of the correct width — without
                // this, `bleedingDays` stays pinned to the initial
                // currentCycle value and ignores manual overrides.
                state.bleedingDays = response.effectiveBleedingDays
                state.showOvulation = response.showOvulation
                state.showFertileWindow = response.showFertileWindow
                Self.parseCalendarEntries(response.entries, into: &state)
                return .none

            case .calendarLoaded(.failure):
                state.isLoadingCalendar = false
                return .none

            case .symptomsLoaded(.success(let symptoms)):
                let key = CalendarFeature.dateKey(state.selectedDate)
                var log = state.loggedDays[key] ?? State.DayLog()
                log.symptoms = symptoms.map(\.symptomType)
                log.severities = Dictionary(
                    uniqueKeysWithValues: symptoms.map { ($0.symptomType, $0.severity) }
                )
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

                state.snapshot.periodDays = periodDays
                state.snapshot.flowIntensity = flowIntensity
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
                return .send(.delegate(.periodDataChanged))

            case .binding, .delegate:
                return .none
            }
        }
    }
}
