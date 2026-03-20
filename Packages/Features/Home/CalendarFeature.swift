import ComposableArchitecture
import Inject
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

        @Presents public var editPeriod: EditPeriodFeature.State?

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
        case editPeriodTapped
        case editPeriod(PresentationAction<EditPeriodFeature.Action>)
        case ariaPromptTalkTapped
        case ariaPromptDismissed
        case loadCalendar
        case calendarLoaded(Result<MenstrualCalendarResponse, Error>)
        case symptomsLoaded(Result<[MenstrualSymptomResponse], Error>)
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case didDismiss(periodDays: Set<String>)
            case openAriaChat(context: String)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.menstrualClient) var menstrualClient
    @Dependency(\.sessionClient) var sessionClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .dismissTapped:
                let periodDays = state.periodDays
                return .run { send in
                    await send(.delegate(.didDismiss(periodDays: periodDays)))
                    await dismiss()
                }

            case .daySelected(let date):
                let day = Calendar.current.startOfDay(for: date)
                state.selectedDate = day
                if day <= Calendar.current.startOfDay(for: Date()) {
                    state.isShowingSymptomSheet = true
                }
                // Load existing symptoms for this date from backend
                return .run { [menstrualClient, sessionClient] send in
                    guard let token = try? await sessionClient.getAccessToken() else { return }
                    let result = await Result {
                        try await menstrualClient.getSymptoms(token, day)
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
                return .run { [menstrualClient, sessionClient] send in
                    if let token = try? await sessionClient.getAccessToken() {
                        for symptom in symptoms {
                            let request = LogSymptomRequest(
                                symptomDate: date,
                                symptomType: symptom,
                                severity: 3
                            )
                            try? await menstrualClient.logSymptom(token, request)
                        }
                    }
                    await send(.saveSymptomsDone, animation: .easeInOut(duration: 0.3))
                }

            case .saveSymptomsDone:
                state.isSavingSymptoms = false
                state.symptomsSaved = true
                // Build Aria prompt based on logged symptoms + phase
                let key = CalendarFeature.dateKey(state.selectedDate)
                let symptoms = state.loggedDays[key]?.symptoms ?? []
                let phase = phaseInfo(
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
                    state.showAriaPrompt = true
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
                return .run { [menstrualClient, sessionClient] send in
                    guard let token = try? await sessionClient.getAccessToken() else { return }
                    let result = await Result {
                        try await menstrualClient.getCalendar(token, start, end)
                    }
                    await send(.calendarLoaded(result))
                }

            case .calendarLoaded(.success(let response)):
                state.isLoadingCalendar = false
                state.calendarEntries = response.entries
                // Populate periodDays from backend calendar entries (confirmed + predicted)
                var serverPeriodDays: Set<String> = []
                var serverPredictedDays: Set<String> = []
                var serverFertileDays: [String: FertilityLevel] = [:]
                var serverOvulationDays: Set<String> = []
                let todayKey = Self.dateKey(Calendar.current.startOfDay(for: Date()))
                for entry in response.entries {
                    let localDay = Self.localDate(from: entry.date)
                    let key = Self.dateKey(localDay)
                    if entry.type == "period" {
                        serverPeriodDays.insert(key)
                        // Future bleeding days from current cycle → show as predicted
                        if key > todayKey {
                            serverPredictedDays.insert(key)
                        }
                    } else if entry.type == "predicted_period" {
                        serverPeriodDays.insert(key)
                        serverPredictedDays.insert(key)
                    } else if entry.type == "fertile", let levelStr = entry.fertilityLevel,
                              let level = FertilityLevel(rawValue: levelStr) {
                        serverFertileDays[key] = level
                    } else if entry.type == "ovulation" {
                        serverOvulationDays.insert(key)
                    }
                }
                // Always use server as source of truth (even if empty)
                state.periodDays = serverPeriodDays
                state.predictedPeriodDays = serverPredictedDays
                state.fertileDays = serverFertileDays
                state.ovulationDays = serverOvulationDays
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

            case .editPeriodTapped:
                // Exclude predicted days from periodDays — EditPeriod shows them separately
                let confirmedDays = state.periodDays.subtracting(state.predictedPeriodDays)
                state.editPeriod = EditPeriodFeature.State(
                    cycleStartDate: state.cycleStartDate,
                    cycleLength: state.cycleLength,
                    bleedingDays: state.bleedingDays,
                    periodDays: confirmedDays,
                    periodFlowIntensity: state.periodFlowIntensity,
                    predictedPeriodDays: state.predictedPeriodDays
                )
                return .none

            case .editPeriod(.presented(.delegate(let delegate))):
                switch delegate {
                case .didSave(let periodDays, let predictedPeriodDays, let flowIntensity):
                    // Use data directly from EditPeriod — already fresh from server
                    state.periodDays = periodDays.union(predictedPeriodDays)
                    state.predictedPeriodDays = predictedPeriodDays
                    state.periodFlowIntensity = flowIntensity

                    if periodDays.isEmpty {
                        let today = Calendar.current.startOfDay(for: Date())
                        state.cycleStartDate = state.menstrualStatus.map {
                            Calendar.current.startOfDay(for: CalendarFeature.localDate(from: $0.currentCycle.startDate))
                        } ?? Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today
                        state.bleedingDays = state.menstrualStatus?.currentCycle.bleedingDays ?? 5
                    } else {
                        CalendarFeature.recomputeCycle(from: &state)
                    }
                    state.editPeriod = nil
                    // Reload calendar to get updated fertile window from server
                    return .send(.loadCalendar)
                }
                return .none

            case .editPeriod:
                return .none

            case .binding, .delegate:
                return .none
            }
        }
        .ifLet(\.$editPeriod, action: \.editPeriod) {
            EditPeriodFeature()
        }
    }

    static func dateKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    /// Converts a server date (UTC midnight) to local midnight for the same calendar day.
    /// Prevents off-by-one when local timezone is west of UTC.
    public static func localDate(from serverDate: Date) -> Date {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: serverDate)
        return Calendar.current.date(from: comps) ?? serverDate
    }

    /// Converts a local midnight date to UTC midnight for the same calendar day.
    /// Use when storing local dates into models that will later be read via localDate(from:).
    public static func utcDate(from localDate: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        return utcCal.date(from: comps) ?? localDate
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
            return "I noticed you're feeling emotionally heavy today. During your period, hormone shifts can amplify everything. Want to talk through it? I'm here."
        case (true, _, _, .luteal):
            return "The luteal phase can bring waves of emotion that feel bigger than usual. You're not imagining it — and you don't have to carry it alone."
        case (true, _, _, _):
            return "I see what you're feeling today. Sometimes just putting it into words helps. Want to explore this together?"
        case (_, true, _, .menstrual):
            return "Your body is working hard right now. I have some gentle relief ideas that might help — want me to walk you through them?"
        case (_, true, _, _):
            return "Pain can be draining in ways that go beyond the physical. I'd love to help you find some comfort today."
        case (_, _, true, _):
            return "Low energy days deserve gentleness, not guilt. I can suggest a few things that might help you recharge — shall we chat?"
        default:
            return "Thank you for checking in with yourself today. Tracking these patterns helps me understand you better. Want to talk about how you're feeling?"
        }
    }

    private static func recomputeCycle(from state: inout State) {
        guard !state.periodDays.isEmpty else { return }
        // Group all period days into consecutive streaks, then pick the
        // most recent streak that starts on or before today.
        let groups = EditPeriodFeature.groupConsecutivePeriods(state.periodDays)
        guard !groups.isEmpty else { return }

        let today = Calendar.current.startOfDay(for: Date())
        // Find the latest period that has already started (startDate <= today)
        let pastGroups = groups.filter { $0.startDate <= today }
        guard let best = pastGroups.last ?? groups.first else { return }

        state.cycleStartDate = best.startDate
        state.bleedingDays = best.dayCount
    }
}

// MARK: - Phase Calculation Helper

private func phaseInfo(
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
    // Limit projection to 12 cycles ahead (~1 year)
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

// MARK: - Symptom Categories

private enum SymptomCategory: String, CaseIterable {
    case physical = "Physical"
    case mood = "Mood"
    case energy = "Energy"
    case sleep = "Sleep"
    case digestive = "Digestive"
    case skin = "Skin & Hair"

    var icon: String {
        switch self {
        case .physical: "figure.run"
        case .mood: "face.smiling"
        case .energy: "bolt.circle"
        case .sleep: "moon.zzz"
        case .digestive: "fork.knife"
        case .skin: "sparkles"
        }
    }

    var symptoms: [SymptomType] {
        switch self {
        case .physical:
            [.cramping, .headache, .backPain, .bloating, .breastTenderness, .nausea,
             .acne, .dizziness, .hotFlashes, .jointPain, .allGood, .fever]
        case .mood:
            [.calm, .happy, .sensitive, .sad, .apathetic, .tired, .angry,
             .lively, .motivated, .anxious, .confident, .irritable, .emotional, .moodSwings]
        case .energy:
            [.lowEnergy, .normalEnergy, .highEnergy, .noStress, .manageableStress, .intenseStress]
        case .sleep:
            [.peacefulSleep, .difficultyFallingAsleep, .restlessSleep, .insomnia]
        case .digestive:
            [.constipation, .diarrhea, .appetiteChanges, .cravings, .hunger]
        case .skin:
            [.normalSkin, .drySkin, .oilySkin, .skinBreakouts, .itchySkin,
             .normalHair, .shinyHair, .oilyHair, .dryHair, .hairLoss]
        }
    }
}

// MARK: - Day Info

private struct CalendarDayInfo {
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let phase: CyclePhase?
    let cycleDay: Int?
    let isPeriodDay: Bool
    let isFertile: Bool
    let fertilityLevel: FertilityLevel?
    let isOvulationDay: Bool
    let isPredicted: Bool
    let isUserMarkedPeriod: Bool
    let flowIntensity: FlowIntensity?
    let hasLog: Bool
    let isFuture: Bool
}

// MARK: - CalendarView

public struct CalendarView: View {
    @ObserveInjection var inject
    @Bindable public var store: StoreOf<CalendarFeature>

    public init(store: StoreOf<CalendarFeature>) {
        self.store = store
    }

    @State private var detailSheetDetent: PresentationDetent = .medium
    @State private var isShowingDayDetail: Bool = false

    private let cal = Calendar.current

    private var months: [Date] {
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        let current = cal.date(from: comps) ?? Date()
        return (-12...12).compactMap { cal.date(byAdding: .month, value: $0, to: current) }
    }

    private func monthId(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: date)
    }

    private var currentMonthId: String {
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        let current = cal.date(from: comps) ?? Date()
        return monthId(current)
    }

    public var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                FeedTopBar(store: store)

                PhaseLegendView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                WeekdayLabelsRow()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(DesignColors.background)

                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(months, id: \.self) { month in
                                Section {
                                    MonthGridView(store: store, month: month)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 20)
                                        .id(monthId(month))
                                } header: {
                                    MonthSectionHeader(date: month)
                                }
                            }
                        }
                        .padding(.bottom, 120)
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 80_000_000)
                            proxy.scrollTo(currentMonthId, anchor: .top)
                        }
                    }
                }
            }

            // Floating buttons
            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        store.send(.logSymptomsTapped)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Circle().strokeBorder(
                                        DesignColors.accentWarm.opacity(0.45),
                                        lineWidth: 1
                                    )
                                }
                                .shadow(color: DesignColors.accentWarm.opacity(0.25), radius: 10, x: 0, y: 4)
                            VStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Log")
                                    .font(.custom("Raleway-SemiBold", size: 10))
                            }
                            .foregroundColor(DesignColors.accentWarm)
                        }
                        .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $isShowingDayDetail) {
            DayDetailPanel(store: store)
                .presentationDetents(
                    [.medium, .large],
                    selection: $detailSheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $store.isShowingSymptomSheet, onDismiss: {
            store.send(.symptomSheetDismissed)
        }) {
            SymptomLoggingSheet(store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusXL)
        }
        .fullScreenCover(item: $store.scope(state: \.editPeriod, action: \.editPeriod)) { editStore in
            EditPeriodView(store: editStore)
        }
        .overlay {
            if store.showAriaPrompt {
                AriaPromptOverlay(
                    message: store.ariaPromptMessage,
                    onTalk: { store.send(.ariaPromptTalkTapped) },
                    onDismiss: { store.send(.ariaPromptDismissed, animation: .spring(response: 0.35, dampingFraction: 0.85)) }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.showAriaPrompt)
            }
        }
        .enableInjection()
    }
}

// MARK: - Feed Top Bar

private struct FeedTopBar: View {
    @Bindable var store: StoreOf<CalendarFeature>

    var body: some View {
        HStack(spacing: 0) {
            Button { store.send(.dismissTapped) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignColors.text)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay { Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5) }
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Calendar")
                .font(.custom("Raleway-Bold", size: 20))
                .foregroundColor(DesignColors.text)

            Spacer()

            Button { store.send(.editPeriodTapped) } label: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CyclePhase.menstrual.orbitColor)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle().strokeBorder(
                                    CyclePhase.menstrual.orbitColor.opacity(0.4),
                                    lineWidth: 1
                                )
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Month Section Header

private struct MonthSectionHeader: View {
    let date: Date

    private var monthYearString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }

    var body: some View {
        HStack {
            Text(monthYearString)
                .font(.custom("Raleway-Bold", size: 16))
                .foregroundColor(DesignColors.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(DesignColors.background)
    }
}

// MARK: - Day Insight Floating Button

private struct DayInsightFloatingButton: View {
    @Bindable var store: StoreOf<CalendarFeature>
    let action: () -> Void

    private var accentColor: Color {
        phaseInfo(
            for: store.selectedDate,
            cycleStartDate: store.cycleStartDate,
            cycleLength: store.cycleLength,
            bleedingDays: store.bleedingDays
        )?.phase.orbitColor ?? DesignColors.accentWarm
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle().strokeBorder(
                            accentColor.opacity(0.45),
                            lineWidth: 1
                        )
                    }
                    .shadow(color: accentColor.opacity(0.25), radius: 10, x: 0, y: 4)
                VStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Insights")
                        .font(.custom("Raleway-SemiBold", size: 10))
                }
                .foregroundColor(accentColor)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.selectedDate)
    }
}

// MARK: - Phase Legend

private struct PhaseLegendView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(CyclePhase.allCases, id: \.self) { phase in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(phase.orbitColor)
                            .frame(width: 7, height: 7)
                        Text(phase.displayName)
                            .font(.custom("Raleway-Medium", size: 11))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(CyclePhase.ovulatory.orbitColor.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .overlay { Circle().strokeBorder(CyclePhase.ovulatory.orbitColor, lineWidth: 1) }
                    Text("Fertile")
                        .font(.custom("Raleway-Medium", size: 11))
                        .foregroundColor(DesignColors.textSecondary)
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(DesignColors.textSecondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .frame(width: 12, height: 12)
                    Text("Predicted")
                        .font(.custom("Raleway-Medium", size: 11))
                        .foregroundColor(DesignColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Weekday Labels

private struct WeekdayLabelsRow: View {
    private let labels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Month Grid

private struct MonthGridView: View {
    @Bindable var store: StoreOf<CalendarFeature>
    let month: Date
    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)


    private var days: [CalendarDayInfo] {
        let cycleStart = cal.startOfDay(for: store.cycleStartDate)
        let cycleLength = store.cycleLength
        let bleedingDays = store.bleedingDays
        let loggedDays = store.loggedDays
        let periodDays = store.periodDays
        let predictedPeriodDays = store.predictedPeriodDays
        let periodFlowIntensity = store.periodFlowIntensity
        let fertileDays = store.fertileDays
        let ovulationDays = store.ovulationDays
        let selectedDate = store.selectedDate
        let displayedMonth = month
        let today = cal.startOfDay(for: Date())

        let gridStart = mondayStartOfGrid(for: displayedMonth)
        var dates = (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }

        // Trim last row if all outside current month
        if dates.count == 42 {
            let lastRow = Array(dates[35...])
            if lastRow.allSatisfy({ cal.component(.month, from: $0) != cal.component(.month, from: displayedMonth) }) {
                dates = Array(dates[..<35])
            }
        }

        return dates.map { date in
            let d = cal.startOfDay(for: date)
            let isCurrentMonth = cal.component(.month, from: date) == cal.component(.month, from: displayedMonth)
            let key = CalendarFeature.dateKey(date)

            // ONLY server data — no local math for period days
            let isServerPeriod = periodDays.contains(key)
            let isServerPredicted = predictedPeriodDays.contains(key)
            let info = phaseInfo(for: d, cycleStartDate: cycleStart, cycleLength: cycleLength, bleedingDays: bleedingDays)
            let cycleDay = info?.cycleDay
            // Phase from server period status; otherwise use local math for non-period phases only
            let phase: CyclePhase? = isServerPeriod ? .menstrual : (info.map { $0.phase == .menstrual ? .follicular : $0.phase })
            // Server-driven fertility data
            let serverFertilityLevel = fertileDays[key]
            let isFertile = serverFertilityLevel != nil
            let isOvulation = ovulationDays.contains(key)

            return CalendarDayInfo(
                date: date,
                dayNumber: cal.component(.day, from: date),
                isCurrentMonth: isCurrentMonth,
                isToday: d == today,
                isSelected: d == selectedDate,
                phase: phase,
                cycleDay: cycleDay,
                isPeriodDay: isServerPeriod,
                isFertile: isFertile,
                fertilityLevel: serverFertilityLevel,
                isOvulationDay: isOvulation,
                isPredicted: isServerPredicted,
                isUserMarkedPeriod: isServerPeriod && !isServerPredicted,
                flowIntensity: periodFlowIntensity[key],
                hasLog: !(loggedDays[key]?.symptoms.isEmpty ?? true),
                isFuture: d > today
            )
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, info in
                CalendarDayCell(info: info)
                    .onTapGesture {
                        guard info.isCurrentMonth, !info.isFuture else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.send(.daySelected(info.date), animation: .spring(response: 0.3, dampingFraction: 0.8))
                    }
            }
        }
    }

    private func mondayStartOfGrid(for month: Date) -> Date {
        var comps = cal.dateComponents([.year, .month], from: month)
        comps.day = 1
        let firstOfMonth = cal.date(from: comps) ?? month
        let weekday = cal.component(.weekday, from: firstOfMonth)
        // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        let daysBack: Int
        switch weekday {
        case 1: daysBack = 6
        case 2: daysBack = 0
        case 3: daysBack = 1
        case 4: daysBack = 2
        case 5: daysBack = 3
        case 6: daysBack = 4
        case 7: daysBack = 5
        default: daysBack = 0
        }
        return cal.date(byAdding: .day, value: -daysBack, to: firstOfMonth) ?? firstOfMonth
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    let info: CalendarDayInfo

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Base fill
                Circle()
                    .fill(fillColor)

                // Fertile day: subtle colored ring
                if info.isFertile && !info.isPeriodDay && info.isCurrentMonth && !info.isSelected {
                    Circle()
                        .strokeBorder(
                            info.fertilityLevel?.color ?? CyclePhase.ovulatory.orbitColor.opacity(0.4),
                            lineWidth: info.isOvulationDay ? 2 : 1.5
                        )
                }

                // Predicted period: dashed border
                if info.isPredicted && info.isPeriodDay && !info.isSelected && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                        )
                        .foregroundColor(CyclePhase.menstrual.orbitColor.opacity(0.4))
                }

                // Today dashed ring
                if info.isToday && info.isCurrentMonth && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundColor(DesignColors.accentWarm)
                }

                // Selection ring
                if info.isSelected && info.isCurrentMonth {
                    Circle()
                        .strokeBorder(
                            info.isUserMarkedPeriod
                                ? Color.white.opacity(0.9)
                                : Color.white.opacity(0.6),
                            lineWidth: 2
                        )
                }

                Text("\(info.dayNumber)")
                    .font(.custom(info.isSelected || info.isToday ? "Raleway-Bold" : "Raleway-SemiBold", size: 14))
                    .foregroundColor(textColor)
                    .offset(y: info.isUserMarkedPeriod && info.isCurrentMonth ? -3 : 0)

                // Period flow droplet indicator
                if info.isUserMarkedPeriod && info.isCurrentMonth {
                    PeriodDropletIndicator(
                        intensity: info.flowIntensity,
                        isOnDark: true
                    )
                    .offset(y: 10)
                }

                // Ovulation day sparkle icon
                if info.isOvulationDay && !info.isPeriodDay && info.isCurrentMonth {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(CyclePhase.ovulatory.orbitColor)
                        .offset(x: 13, y: -13)
                }
            }
            .frame(width: 40, height: 40)
            .shadow(
                color: info.isUserMarkedPeriod
                    ? CyclePhase.menstrual.glowColor.opacity(0.25)
                    : info.isOvulationDay && !info.isPeriodDay
                        ? CyclePhase.ovulatory.glowColor.opacity(0.2)
                        : .clear,
                radius: 6, x: 0, y: 2
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: info.isSelected)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: info.isUserMarkedPeriod)

            // Today label, log indicator, fertile indicator, or phase dot
            if info.isToday && info.isCurrentMonth {
                Text("Today")
                    .font(.custom("Raleway-Bold", size: 8))
                    .foregroundColor(DesignColors.accentWarm)
                    .frame(height: 10)
            } else if info.hasLog && info.isCurrentMonth {
                Circle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 5, height: 5)
                    .frame(height: 3)
            } else if info.isFertile && !info.isPeriodDay && info.isCurrentMonth {
                // Fertile indicator dot — colored by level
                Circle()
                    .fill(info.fertilityLevel?.color ?? CyclePhase.ovulatory.orbitColor.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .frame(height: 3)
            } else {
                Circle()
                    .fill(phaseDotColor == .clear ? Color.clear : phaseDotColor)
                    .frame(width: 5, height: 5)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(info.isCurrentMonth ? (info.isFuture ? 0.35 : 1) : 0.18)
    }

    private var fillColor: Color {
        guard info.isCurrentMonth else { return .clear }

        // User-marked period days always red
        if info.isUserMarkedPeriod {
            return CyclePhase.menstrual.orbitColor.opacity(info.isSelected ? 0.9 : 0.75)
        }

        // Predicted period: light red tint
        if info.isPredicted && info.isPeriodDay {
            return CyclePhase.menstrual.orbitColor.opacity(info.isSelected ? 0.35 : 0.18)
        }

        // Ovulation day: golden tint
        if info.isOvulationDay && !info.isPeriodDay {
            return CyclePhase.ovulatory.orbitColor.opacity(info.isSelected ? 0.35 : 0.18)
        }

        // Fertile days: subtle tint based on level
        if info.isFertile && !info.isPeriodDay, let level = info.fertilityLevel {
            let baseOpacity: Double = info.isSelected ? 0.25 : 0.12
            return level.color.opacity(baseOpacity)
        }

        // Everything else: no fill (clean/blank)
        return .clear
    }

    private var textColor: Color {
        guard info.isCurrentMonth else { return DesignColors.textPlaceholder.opacity(0.35) }
        if info.isUserMarkedPeriod { return .white }
        if info.isSelected { return DesignColors.text }
        return DesignColors.text.opacity(0.75)
    }

    private var phaseDotColor: Color {
        guard info.isCurrentMonth,
              !info.isUserMarkedPeriod,
              !info.isPeriodDay,
              let phase = info.phase
        else { return .clear }
        return phase.orbitColor
    }
}

// MARK: - Period Droplet Indicator

private struct PeriodDropletIndicator: View {
    let intensity: FlowIntensity?
    var isOnDark: Bool = false

    var body: some View {
        let resolved = intensity ?? .medium
        Group {
            if resolved == .spotting {
                Circle()
                    .fill(isOnDark ? Color.white.opacity(0.8) : CyclePhase.menstrual.orbitColor.opacity(0.6))
                    .frame(width: 5, height: 5)
            } else {
                HStack(spacing: 1) {
                    ForEach(0..<resolved.dropletCount, id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 7, weight: .semibold))
                    }
                }
                .foregroundColor(isOnDark ? .white : CyclePhase.menstrual.orbitColor.opacity(0.8))
            }
        }
    }
}

// MARK: - Day Detail Panel

private struct DayDetailPanel: View {
    @Bindable var store: StoreOf<CalendarFeature>

    private var selectedPhaseInfo: (phase: CyclePhase, cycleDay: Int, isPredicted: Bool)? {
        let info = phaseInfo(for: store.selectedDate, cycleStartDate: store.cycleStartDate, cycleLength: store.cycleLength, bleedingDays: store.bleedingDays)
        guard let info else { return nil }

        let isPast = store.selectedDate <= Calendar.current.startOfDay(for: Date())
        if isPast && !isSelectedPeriodDay && !info.isPredicted {
            return nil
        }

        return info
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: store.selectedDate)
    }

    private var loggedSymptoms: [SymptomType] {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return (store.loggedDays[key]?.symptoms ?? []).compactMap { SymptomType(rawValue: $0) }
    }

    private var periodKey: String { CalendarFeature.dateKey(store.selectedDate) }
    private var isSelectedPeriodDay: Bool { store.periodDays.contains(periodKey) }
    private var selectedFertilityLevel: FertilityLevel? { store.fertileDays[periodKey] }
    private var isSelectedOvulationDay: Bool { store.ovulationDays.contains(periodKey) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                PhaseBannerRow(
                    phase: selectedPhaseInfo?.phase,
                    cycleDay: selectedPhaseInfo?.cycleDay,
                    dateString: formattedDate,
                    isPredicted: selectedPhaseInfo?.isPredicted ?? false
                )

                // Fertility info card
                if let level = selectedFertilityLevel {
                    FertilityInfoCard(
                        level: level,
                        isOvulationDay: isSelectedOvulationDay
                    )
                }

                AriaInsightCard(
                    phase: selectedPhaseInfo?.phase,
                    cycleDay: selectedPhaseInfo?.cycleDay,
                    isPredicted: selectedPhaseInfo?.isPredicted ?? false
                )


            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
    }
}

// MARK: - Phase Banner Row

private struct PhaseBannerRow: View {
    let phase: CyclePhase?
    let cycleDay: Int?
    let dateString: String
    let isPredicted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(phase?.orbitColor.opacity(0.12) ?? DesignColors.structure.opacity(0.12))
                Text(phase?.emoji ?? "🗓️")
                    .font(.system(size: 20))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(dateString)
                    .font(.custom("Raleway-SemiBold", size: 15))
                    .foregroundColor(DesignColors.text)

                if let phase, let day = cycleDay {
                    HStack(spacing: 6) {
                        Text("\(phase.displayName) · Day \(day)")
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundColor(phase.orbitColor)
                        if isPredicted {
                            Text("Predicted")
                                .font(.custom("Raleway-Medium", size: 10))
                                .foregroundColor(phase.orbitColor.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .strokeBorder(phase.orbitColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                }
                        }
                    }
                    // Medical hormone context
                    Text(phase.medicalDescription)
                        .font(.custom("Raleway-Regular", size: 11.5))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                } else {
                    Text("Outside current cycle")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            if let phase {
                Text(phase.description)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(phase.orbitColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(phase.orbitColor.opacity(0.1))
                            .overlay {
                                Capsule().strokeBorder(phase.orbitColor.opacity(0.3), lineWidth: 0.5)
                            }
                    }
            }
        }
    }
}

// MARK: - Fertility Info Card

private struct FertilityInfoCard: View {
    let level: FertilityLevel
    let isOvulationDay: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(level.color.opacity(0.15))
                Image(systemName: isOvulationDay ? "sparkle" : "leaf.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(level.color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isOvulationDay ? "Ovulation Day" : "Fertile Window")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .foregroundColor(DesignColors.text)
                    Text(level.displayName)
                        .font(.custom("Raleway-Medium", size: 10))
                        .foregroundColor(level.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(level.color.opacity(0.12))
                                .overlay { Capsule().strokeBorder(level.color.opacity(0.3), lineWidth: 0.5) }
                        }
                }
                Text(fertilityDescription)
                    .font(.custom("Raleway-Regular", size: 11.5))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer()

            // Probability badge
            Text(level.probability)
                .font(.custom("Raleway-Bold", size: 13))
                .foregroundColor(level.color)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(level.color.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(level.color.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    private var fertilityDescription: String {
        if isOvulationDay {
            return "Egg is released today. Highest chance of conception within the next 12-24 hours."
        }
        switch level {
        case .peak: return "Peak fertility. The egg may be released today or tomorrow."
        case .high: return "High fertility. Sperm can survive up to 5 days waiting for ovulation."
        case .medium: return "Moderate fertility. You're entering the fertile window."
        case .low: return "Low but possible fertility. Early or late in the fertile window."
        }
    }
}

// MARK: - Aria Insight Card

private struct AriaInsightCard: View {
    let phase: CyclePhase?
    let cycleDay: Int?
    let isPredicted: Bool
    @State private var displayedText: String = ""
    @State private var animTask: Task<Void, Never>?

    // swiftlint:disable:next function_body_length
    private var fullInsight: String {
        guard let day = cycleDay else {
            return "Log your cycle start date to receive personalized AI-powered insights for every day of your cycle."
        }
        let p = isPredicted
        switch day {
        case 1:  return p ? "Your period is about to begin. Rest, warmth, and iron-rich foods will make a real difference in the days ahead."
                          : "Day 1 — your cycle resets. Honour the heaviness with rest. Warm compresses and magnesium-rich foods ease cramps."
        case 2:  return p ? "Flow will likely be at its heaviest. Clear your schedule where you can and lean into slower movement."
                          : "Flow peaks today for most. Energy is at its lowest — this is not the day to push hard. Your body is doing profound work."
        case 3:  return p ? "The sharpest fatigue starts to ease. Gentle walks and warming meals will support your recovery."
                          : "The edge softens today. A little iron and vitamin C together — think spinach with lemon — will help replenish what you're losing."
        case 4:  return p ? "Flow lightens and mood begins to lift. A good day to re-engage with light tasks."
                          : "Lighter flow, lighter mood. Estrogen is quietly beginning its rise. You may notice a small but real shift in your energy."
        case 5:  return p ? "Your period is nearly over. Expect a noticeable lift in energy in the coming days."
                          : "Last day of bleeding for most. The fog is clearing — notice how differently your body feels compared to day 1."
        case 6:  return p ? "Follicular phase begins. Curiosity and motivation will build steadily over the next week."
                          : "Estrogen climbs and so does your drive. A great day to revisit goals or start something you've been putting off."
        case 7:  return p ? "Mental clarity will sharpen. This is an excellent window for focused, deep work."
                          : "Your brain is running cleaner today. Verbal fluency and memory are measurably stronger in the follicular phase — use it."
        case 8:  return p ? "Creative energy is building. Plan space for ideas, writing, or any work that rewards fresh thinking."
                          : "Creativity is near its peak. Ideas flow more freely now. A whiteboard session, a new recipe, a song — go for it."
        case 9:  return p ? "Social magnetism increases. Conversations, networking, and connection will feel more natural and rewarding."
                          : "You're more persuasive and charismatic today than at almost any other point in your cycle. Own it."
        case 10: return p ? "Confidence and focus compound. Ambitious projects started now tend to gain real momentum."
                          : "Estrogen is high and your threshold for stress is elevated. Tackle the hard conversation or the bold project today."
        case 11: return p ? "Energy approaches its monthly peak. Schedule the things that demand your best."
                          : "You're close to your peak — physically and mentally. Your body is primed for intensity, connection, and performance."
        case 12: return p ? "LH surge is imminent. Expect a noticeable spike in drive and confidence."
                          : "The pre-ovulation surge is here. Your body temperature rises slightly and so does your appetite for challenge."
        case 13: return p ? "Tomorrow may be ovulation. Your magnetism and verbal skills are at their monthly high."
                          : "Peak estrogen and rising LH. Your face, voice, and posture subtly shift — research confirms you appear and feel most confident today."
        case 14: return p ? "Ovulation is likely today. High energy, strong communication, and heightened senses are all normal."
                          : "Ovulation day. You are at peak vitality — strong, social, and sharp. Schedule your most important meeting or workout today."
        case 15: return p ? "Progesterone begins rising. Energy stays high but will gradually soften inward."
                          : "The shift begins. Progesterone climbs and your body starts a quieter, more inward phase. You still have plenty of fuel."
        case 16: return p ? "Energy remains good but starts transitioning. Begin wrapping up high-output work."
                          : "A bridge day — still capable of high output, but your nervous system will thank you for starting to taper intensity."
        case 17: return p ? "Luteal phase begins. Structured routines and nourishing meals become more important now."
                          : "Progesterone dominates. Stability and routine feel more grounding than novelty today. Lean in."
        case 18: return p ? "Introspective energy rises. Good for journaling, detailed work, and creative finishing."
                          : "You're entering a 'finishing' mode — detail-oriented, discerning. Great for editing, refining, and deep solo work."
        case 19: return p ? "A calmer, more grounded window. Steady output is very achievable with the right pacing."
                          : "Progesterone's calming effect is real. Use this steadier emotional state for meaningful conversations you've been postponing."
        case 20: return p ? "Your body will need more nourishment. Prioritise protein, healthy fats, and complex carbs."
                          : "Metabolism speeds up slightly in the luteal phase — your body genuinely needs more fuel. Don't fight the hunger."
        case 21: return p ? "PMS symptoms may begin. Reduce caffeine and alcohol, increase magnesium and omega-3s."
                          : "If PMS arrives, it typically starts around now. Magnesium-rich foods — dark chocolate, pumpkin seeds, avocado — genuinely help."
        case 22: return p ? "Cravings will likely increase. They're hormonal, not a lack of willpower — nourish yourself without guilt."
                          : "Carbohydrate cravings peak because serotonin dips with progesterone. Complex carbs stabilise both blood sugar and mood."
        case 23: return p ? "Energy dips become more pronounced. Protect your sleep and reduce high-intensity training."
                          : "Your body is working hard beneath the surface. Swap intense workouts for yoga or walking — recovery is the real work now."
        case 24: return p ? "Emotional sensitivity heightens. Extra rest and boundary-setting will serve you well."
                          : "Your amygdala is more reactive today. It's not you overreacting — it's biology. Name it, and give yourself more space."
        case 25: return p ? "Pre-menstrual phase deepens. Slow down, hydrate, and reduce commitments where possible."
                          : "Inflammation can rise in the late luteal phase. Anti-inflammatory foods — turmeric, berries, oily fish — ease the approach to your period."
        case 26: return p ? "Fatigue and irritability may peak. Protect your evenings and communicate your needs clearly."
                          : "You're in the final descent. Be gentle with yourself and honest with others about your capacity right now."
        case 27: return p ? "One or two days remain. Rest as much as possible and prepare your body for the reset ahead."
                          : "Almost there. Your body is preparing to shed. Heat, rest, and solitude are the best gifts you can give yourself today."
        case 28: return p ? "Your cycle completes tomorrow. The rhythm continues — each cycle is data about your health."
                          : "Cycle day 28 — the last page before a new chapter. Reflect on this month: what your body asked for, what you gave it."
        default:
            let phase = phase
            switch phase {
            case .menstrual:  return p ? "Your period is near. Rest and warmth are your allies." : "Rest deeply. Your body is doing important work."
            case .follicular: return p ? "Energy and clarity are building. Make space for bold ideas." : "Estrogen is rising — your focus and creativity follow."
            case .ovulatory:  return p ? "Peak energy approaches. Show up fully." : "You're at your most vital. Make it count."
            case .luteal:     return p ? "Turn inward. Nourish and protect your energy." : "Slow down with intention. This phase rewards rest and reflection."
            case nil:         return "Log your cycle start date to receive personalized AI-powered insights for every day of your cycle."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Aria")
                    .font(.custom("Raleway-Bold", size: 14))
                    .foregroundColor(DesignColors.text)
                Spacer()
                Text(isPredicted ? "AI Prediction" : "AI Insight")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.5))
            }

            Text(displayedText.isEmpty ? " " : displayedText)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundColor(DesignColors.text.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if displayedText.count == fullInsight.count && !displayedText.isEmpty {
                Text("Powered by Aria · Personalized AI")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.45))
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentWarm.opacity(0.45),
                                    DesignColors.accentSecondary.opacity(0.2),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .onAppear { startTypewriter() }
        .onChange(of: cycleDay) { _, _ in startTypewriter() }
        .onChange(of: isPredicted) { _, _ in startTypewriter() }
        .onDisappear {
            animTask?.cancel()
            animTask = nil
        }
    }

    private func startTypewriter() {
        animTask?.cancel()
        displayedText = ""
        let text = fullInsight
        animTask = Task { @MainActor in
            for char in text {
                guard !Task.isCancelled else { break }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}

// MARK: - Symptom Chips Row

private struct SymptomChipsRow: View {
    let symptoms: [SymptomType]
    let phase: CyclePhase?
    let onLogTapped: () -> Void

    private var accentColor: Color { phase?.orbitColor ?? DesignColors.accentWarm }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S LOG")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.55))
                    .tracking(2)
                Spacer()
                Button(action: onLogTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: symptoms.isEmpty ? "plus" : "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text(symptoms.isEmpty ? "Log" : "Edit")
                            .font(.custom("Raleway-SemiBold", size: 12))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(accentColor.opacity(0.1))
                            .overlay { Capsule().strokeBorder(accentColor.opacity(0.35), lineWidth: 0.5) }
                    }
                }
                .buttonStyle(.plain)
            }

            if symptoms.isEmpty {
                Text("Nothing logged — tap Log to track how you feel.")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(symptoms) { symptom in
                            LoggedSymptomChip(symptom: symptom, accentColor: accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Logged Symptom Chip

private struct LoggedSymptomChip: View {
    let symptom: SymptomType
    let accentColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symptom.sfSymbol)
                .font(.system(size: 11, weight: .medium))
            Text(symptom.displayName)
                .font(.custom("Raleway-Medium", size: 12))
        }
        .foregroundColor(accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(accentColor.opacity(0.1))
                .overlay { Capsule().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5) }
        }
    }
}

// MARK: - Aria Prompt Overlay

private struct AriaPromptOverlay: View {
    let message: String
    let onTalk: () -> Void
    let onDismiss: () -> Void

    @State private var displayedText: String = ""
    @State private var animTask: Task<Void, Never>?
    @State private var showButtons: Bool = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Aria avatar + header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.accentWarm.opacity(0.8),
                                            DesignColors.accent.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aria noticed something")
                                .font(.custom("Raleway-Bold", size: 16))
                                .foregroundColor(DesignColors.text)
                            Text("Your AI companion")
                                .font(.custom("Raleway-Regular", size: 12))
                                .foregroundColor(DesignColors.textSecondary)
                        }

                        Spacer()

                        Button { onDismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(DesignColors.textSecondary.opacity(0.5))
                                .frame(width: 30, height: 30)
                                .background {
                                    Circle().fill(Color.white.opacity(0.08))
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    // Typewriter message
                    Text(displayedText.isEmpty ? " " : displayedText)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(DesignColors.text.opacity(0.9))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Action buttons
                    if showButtons {
                        VStack(spacing: 10) {
                            Button { onTalk() } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Talk to Aria")
                                        .font(.custom("Raleway-Bold", size: 15))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [DesignColors.accentWarm, DesignColors.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
                                }
                            }
                            .buttonStyle(.plain)

                            Button { onDismiss() } label: {
                                Text("Maybe later")
                                    .font(.custom("Raleway-Medium", size: 14))
                                    .foregroundColor(DesignColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(DesignColors.background.opacity(0.97))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.accentWarm.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        }
                        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { startTypewriter() }
        .onDisappear { animTask?.cancel() }
    }

    private func startTypewriter() {
        animTask?.cancel()
        displayedText = ""
        showButtons = false
        let text = message
        animTask = Task { @MainActor in
            for char in text {
                guard !Task.isCancelled else { break }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
    }
}

// MARK: - Symptom Logging Sheet

private struct SymptomLoggingSheet: View {
    @Bindable var store: StoreOf<CalendarFeature>

    private var selectedSymptoms: Set<String> {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return Set(store.loggedDays[key]?.symptoms ?? [])
    }

    private var selectedSymptomTypes: [SymptomType] {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return (store.loggedDays[key]?.symptoms ?? []).compactMap { SymptomType(rawValue: $0) }
    }

    private var selectedPhase: CyclePhase? {
        phaseInfo(for: store.selectedDate, cycleStartDate: store.cycleStartDate, cycleLength: store.cycleLength, bleedingDays: store.bleedingDays)?.phase
    }

    private var accentColor: Color {
        selectedPhase?.orbitColor ?? DesignColors.accentWarm
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: store.selectedDate)
    }

    private var filteredCategories: [(SymptomCategory, [SymptomType])] {
        let search = store.symptomSearchText.lowercased().trimmingCharacters(in: .whitespaces)
        return SymptomCategory.allCases.compactMap { cat in
            let filtered = search.isEmpty ? cat.symptoms : cat.symptoms.filter {
                $0.displayName.lowercased().contains(search)
            }
            return filtered.isEmpty ? nil : (cat, filtered)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How are you feeling?")
                            .font(.custom("Raleway-Bold", size: 20))
                            .foregroundColor(DesignColors.text)
                        Text(formattedDate)
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                    Spacer()
                    Button { store.send(.symptomSheetDismissed) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DesignColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle().fill(.ultraThinMaterial)
                                    .overlay { Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                // Summary of logged symptoms
                if !selectedSymptomTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOGGED")
                            .font(.custom("Raleway-Regular", size: 11))
                            .foregroundColor(DesignColors.textSecondary.opacity(0.65))
                            .tracking(2)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(selectedSymptomTypes) { symptom in
                                HStack(spacing: 8) {
                                    Image(systemName: symptom.sfSymbol)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(accentColor)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(accentColor.opacity(0.15))
                                        }
                                    Text(symptom.displayName)
                                        .font(.custom("Raleway-SemiBold", size: 13))
                                        .foregroundColor(DesignColors.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        store.send(.symptomToggled(symptom), animation: .spring(response: 0.25, dampingFraction: 0.75))
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(DesignColors.textSecondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.6))
                    TextField("Search symptoms...", text: $store.symptomSearchText)
                        .font(.custom("Raleway-Regular", size: 14))
                        .foregroundColor(DesignColors.text)
                    if !store.symptomSearchText.isEmpty {
                        Button { store.symptomSearchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(DesignColors.textSecondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        ForEach(filteredCategories, id: \.0.rawValue) { (category, symptoms) in
                            SymptomCategorySection(
                                category: category,
                                symptoms: symptoms,
                                selectedSymptoms: selectedSymptoms,
                                selectedPhase: selectedPhase,
                                onToggle: {
                                    store.send(.symptomToggled($0), animation: .spring(response: 0.25, dampingFraction: 0.75))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }

            // Save button
            if !selectedSymptoms.isEmpty {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [DesignColors.background.opacity(0), DesignColors.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)

                    Button {
                        store.send(.saveSymptomsTapped, animation: .easeInOut(duration: 0.3))
                    } label: {
                        HStack(spacing: 8) {
                            if store.isSavingSymptoms {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else if store.symptomsSaved {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(store.symptomsSaved ? "Saved!" : store.isSavingSymptoms ? "Saving..." : "Save \(selectedSymptoms.count) symptom\(selectedSymptoms.count == 1 ? "" : "s")")
                                .font(.custom("Raleway-Bold", size: 16))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: store.symptomsSaved
                                            ? [Color.green, Color.green]
                                            : [accentColor, accentColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: (store.symptomsSaved ? Color.green : accentColor).opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isSavingSymptoms || store.symptomsSaved)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
                .background(DesignColors.background)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedSymptoms.isEmpty)
    }
}

// MARK: - Symptom Category Section

private struct SymptomCategorySection: View {
    let category: SymptomCategory
    let symptoms: [SymptomType]
    let selectedSymptoms: Set<String>
    let selectedPhase: CyclePhase?
    let onToggle: (SymptomType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(selectedPhase?.orbitColor ?? DesignColors.accentWarm)
                Text(category.rawValue.uppercased())
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.65))
                    .tracking(2)
            }

            WrappingLayout(spacing: 8, lineSpacing: 8) {
                ForEach(symptoms) { symptom in
                    let isSelected = selectedSymptoms.contains(symptom.rawValue)
                    SymptomChipButton(
                        symptom: symptom,
                        isSelected: isSelected,
                        selectedPhase: selectedPhase,
                        onTap: { onToggle(symptom) }
                    )
                }
            }
        }
    }
}

// MARK: - Wrapping Layout

private struct WrappingLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: height + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Symptom Chip Button

private struct SymptomChipButton: View {
    let symptom: SymptomType
    let isSelected: Bool
    let selectedPhase: CyclePhase?
    let onTap: () -> Void

    private var fillColor: Color { selectedPhase?.orbitColor ?? DesignColors.accentWarm }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: symptom.sfSymbol)
                    .font(.system(size: 11, weight: .medium))
                Text(symptom.displayName)
                    .font(.custom("Raleway-Medium", size: 13))
            }
            .foregroundColor(isSelected ? .white : DesignColors.text.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? fillColor : DesignColors.structure.opacity(0.12))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isSelected ? fillColor : DesignColors.structure.opacity(0.3),
                                lineWidth: isSelected ? 0 : 0.5
                            )
                    }
                    .shadow(color: isSelected ? fillColor.opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cycle Length Row

private struct CycleLengthRow: View {
    let cycleLength: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignColors.textSecondary.opacity(0.55))

            Text("Cycle Length")
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(DesignColors.textSecondary.opacity(0.65))

            Spacer()

            HStack(spacing: 4) {
                stepButton(icon: "minus", action: onDecrease)

                Text("\(cycleLength)d")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundColor(DesignColors.text)
                    .frame(minWidth: 34, alignment: .center)

                stepButton(icon: "plus", action: onIncrease)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignColors.text.opacity(0.7))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay { Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Calendar") {
    CalendarView(
        store: Store(initialState: CalendarFeature.State(menstrualStatus: .mock)) {
            CalendarFeature()
        }
    )
}
