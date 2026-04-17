import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - EditPeriodFeature

@Reducer
public struct EditPeriodFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var initialMonth: Date
        public var periodDays: Set<String>
        public var periodFlowIntensity: [String: FlowIntensity]
        public var selectedPeriodDay: String?
        public var isUpdatingPredictions: Bool = false
        public var predictionsDone: Bool = false
        public var originalPeriodDays: Set<String> = []
        public var originalFlowIntensity: [String: FlowIntensity] = [:]
        /// Predicted period days from server (read-only, shown with dashed style)
        public var predictedPeriodDays: Set<String> = []

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
            var comps = Calendar.current.dateComponents([.year, .month], from: target)
            comps.day = 1
            self.initialMonth = Calendar.current.date(from: comps) ?? target
            self.periodDays = periodDays
            self.periodFlowIntensity = periodFlowIntensity
            self.originalPeriodDays = periodDays
            self.originalFlowIntensity = periodFlowIntensity
            self.predictedPeriodDays = predictedPeriodDays
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
                state.periodDays = serverDays
                state.originalPeriodDays = serverDays
                state.predictedPeriodDays = predicted
                print(
                    "[EditPeriod] calendarLoaded: periodDays=\(serverDays.sorted()), predictedDays=\(predicted.sorted())"
                )
                return .none

            case .calendarLoaded(.failure):
                return .none

            case .dayTapped(let date):
                let cal = Calendar.current
                let key = Self.dateKey(date)
                if state.periodDays.contains(key) {
                    let today = cal.startOfDay(for: Date())
                    // Remove this day + all future period days after it
                    state.periodDays.remove(key)
                    state.periodFlowIntensity.removeValue(forKey: key)
                    for i in 1...30 {
                        guard let d = cal.date(byAdding: .day, value: i, to: date),
                            cal.startOfDay(for: d) >= today
                        else { continue }
                        let k = Self.dateKey(d)
                        if state.periodDays.contains(k) {
                            state.periodDays.remove(k)
                            state.periodFlowIntensity.removeValue(forKey: k)
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
                        return state.periodDays.contains(Self.dateKey(neighbor))
                    })

                    if isAdjacent {
                        state.periodDays.insert(key)
                        state.periodFlowIntensity[key] = .medium
                    } else {
                        // Auto-fill using user's average bleeding days
                        let fillCount = max(state.bleedingDays, 3)
                        for i in 0..<fillCount {
                            guard let d = cal.date(byAdding: .day, value: i, to: date)
                            else { break }
                            let k = Self.dateKey(d)
                            state.periodDays.insert(k)
                            state.periodFlowIntensity[k] = .medium
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

// MARK: - EditPeriodView

public struct EditPeriodView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<EditPeriodFeature>
    @State private var appeared = false

    private let cal = Calendar.current

    // 12 months back → 1 month forward (computed once)
    private static let allMonthsCache: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.year, .month], from: today)
        comps.day = 1
        let thisMonth = cal.date(from: comps) ?? today
        return (-12...1).compactMap { cal.date(byAdding: .month, value: $0, to: thisMonth) }
    }()

    private var allMonths: [Date] { Self.allMonthsCache }

    private func monthID(_ month: Date) -> String {
        CalendarView.monthIdFormatter.string(from: month)
    }

    public init(store: StoreOf<EditPeriodFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                editHeader

                // Prediction update banner
                if store.isUpdatingPredictions || store.predictionsDone {
                    predictionBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                weekdayLabels
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                Divider()
                    .overlay(DesignColors.structure.opacity(0.15))

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(allMonths, id: \.self) { month in
                                VStack(spacing: 0) {
                                    monthSectionHeader(month)
                                    monthGrid(for: month)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 8)
                                }
                                .id(monthID(month))
                            }
                            Color.clear.frame(height: 140)
                        }
                    }
                    .background(DesignColors.background)
                    .onAppear {
                        proxy.scrollTo(monthID(store.initialMonth), anchor: .top)
                    }
                }
            }

            // Bottom overlay: save button
            VStack(spacing: 0) {
                if store.hasChanges && !store.isUpdatingPredictions {
                    saveButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.96)
        .animation(.spring(response: 0.15, dampingFraction: 0.6, blendDuration: 0), value: appeared)
        .onAppear {
            store.send(.appeared)
            appeared = true
        }
        .enableInjection()
    }

    // MARK: - Prediction Banner

    private var predictionBanner: some View {
        let isDone = store.predictionsDone

        return HStack(spacing: 14) {
            ZStack {
                if isDone {
                    // Checkmark
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    // Pulsing rings
                    Circle()
                        .stroke(DesignColors.accentSecondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulseScale)

                    Circle()
                        .stroke(DesignColors.accentWarm.opacity(0.2), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseScale * 0.9)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 36, height: 36)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDone ? "Predictions updated" : "Updating predictions")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundColor(DesignColors.text)
                    .contentTransition(.numericText())

                Text(isDone ? "Your calendar is up to date" : "Analyzing your cycle patterns...")
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
                    .foregroundColor(DesignColors.textSecondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignColors.accent.opacity(0.15),
                                    DesignColors.roseTaupeLight.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentSecondary.opacity(0.4),
                                    DesignColors.structure.opacity(0.2),
                                    DesignColors.accent.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: DesignColors.accentSecondary.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulseScale = 1.15 } }
    }

    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Header

    private var editHeader: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.cancelTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignColors.text)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Period")
                    .font(.raleway("Bold", size: 24, relativeTo: .title))
                    .foregroundColor(DesignColors.text)

                Text("Tap days to mark or remove")
                    .font(.raleway("Regular", size: 13, relativeTo: .caption))
                    .foregroundColor(DesignColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Weekday Labels

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { label in
                Text(label)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Section

    private func monthSectionHeader(_ month: Date) -> some View {
        let title = DateFormatter.monthYear.string(from: month)

        return HStack {
            Text(title)
                .font(.raleway("Bold", size: 16, relativeTo: .headline))
                .foregroundColor(DesignColors.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(DesignColors.background)
    }

    // MARK: - Month Grid

    private func monthGrid(for month: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        let days = gridDays(for: month)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days) { info in
                EditDayCellView(info: info)
                    .onTapGesture {
                        let today = cal.startOfDay(for: Date())
                        guard info.isCurrentMonth, info.date <= today else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.send(.dayTapped(info.date), animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }
            }
        }
    }

    fileprivate struct EditDayInfo: Equatable, Identifiable {
        let id: String // "yyyy-MM-dd"
        let date: Date
        let dayNumber: Int
        let isCurrentMonth: Bool
        let isToday: Bool
        var isPeriodDay: Bool
        var isPredictedPeriod: Bool
        let isFuture: Bool
    }

    private func gridDays(for month: Date) -> [EditDayInfo] {
        let today = cal.startOfDay(for: Date())
        let gridStart = mondayStartOfGrid(for: month)
        var dates = (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }

        if dates.count == 42 {
            let lastRow = Array(dates[35...])
            let displayMonth = cal.component(.month, from: month)
            if lastRow.allSatisfy({ cal.component(.month, from: $0) != displayMonth }) {
                dates = Array(dates[..<35])
            }
        }

        return dates.map { date in
            let d = cal.startOfDay(for: date)
            let isCurrentMonth = cal.component(.month, from: date) == cal.component(.month, from: month)
            let key = EditPeriodFeature.dateKey(date)

            return EditDayInfo(
                id: key,
                date: date,
                dayNumber: cal.component(.day, from: date),
                isCurrentMonth: isCurrentMonth,
                isToday: d == today,
                isPeriodDay: store.periodDays.contains(key),
                isPredictedPeriod: store.predictedPeriodDays.contains(key),
                isFuture: d > today
            )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DesignColors.background.opacity(0), DesignColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

            Button {
                store.send(.saveTapped, animation: .easeInOut(duration: 0.3))
            } label: {
                Text("Save Period")
                    .font(.raleway("Bold", size: 17, relativeTo: .headline))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        CyclePhase.menstrual.orbitColor, CyclePhase.menstrual.orbitColor.opacity(0.8),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.2), Color.clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                            .shadow(color: CyclePhase.menstrual.glowColor.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(DesignColors.background)
    }

    // MARK: - Helpers

    private static let displayDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt
    }()

    private func dateLabel(for key: String) -> String {
        guard let date = DateFormatter.dayKey.date(from: key) else { return key }
        return Self.displayDateFormatter.string(from: date)
    }

    private func mondayStartOfGrid(for month: Date) -> Date {
        var comps = cal.dateComponents([.year, .month], from: month)
        comps.day = 1
        let firstOfMonth = cal.date(from: comps) ?? month
        let weekday = cal.component(.weekday, from: firstOfMonth)
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

// MARK: - Edit Day Cell View

private struct EditDayCellView: View {
    let info: EditPeriodView.EditDayInfo

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if info.isPeriodDay && info.isCurrentMonth {
                    if info.isFuture {
                        Circle()
                            .fill(CyclePhase.menstrual.orbitColor.opacity(0.25))
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                    )
                                    .foregroundColor(CyclePhase.menstrual.orbitColor.opacity(0.6))
                            }
                    } else {
                        Circle()
                            .fill(CyclePhase.menstrual.orbitColor.opacity(0.75))
                    }
                }

                if info.isPredictedPeriod && !info.isPeriodDay && info.isCurrentMonth {
                    Circle()
                        .fill(CyclePhase.menstrual.orbitColor.opacity(0.15))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                                .foregroundColor(CyclePhase.menstrual.orbitColor.opacity(0.5))
                        }
                }

                if info.isToday && !info.isPeriodDay && !info.isPredictedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundColor(DesignColors.accentWarm)
                }

                Text("\(info.dayNumber)")
                    .font(
                        .raleway(
                            info.isPeriodDay || info.isToday ? "Bold" : "SemiBold",
                            size: 16,
                            relativeTo: .body
                        )
                    )
                    .foregroundColor(dayTextColor)
            }
            .frame(width: 46, height: 46)
            .shadow(
                color: info.isPeriodDay
                    ? CyclePhase.menstrual.glowColor.opacity(0.15)
                    : .clear,
                radius: 6,
                x: 0,
                y: 2
            )

            if info.isToday && info.isCurrentMonth {
                Text("Today")
                    .font(.raleway("Bold", size: 8, relativeTo: .caption2))
                    .foregroundColor(DesignColors.accentWarm)
                    .frame(height: 10)
            } else {
                Color.clear.frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(
            info.isCurrentMonth ? (info.isFuture && !info.isPeriodDay && !info.isPredictedPeriod ? 0.35 : 1) : 0.18
        )
    }

    private var dayTextColor: Color {
        guard info.isCurrentMonth else { return DesignColors.textPlaceholder.opacity(0.35) }
        if info.isPeriodDay && !info.isFuture { return .white }
        if info.isFuture { return DesignColors.textSecondary.opacity(0.4) }
        if info.isToday { return DesignColors.text }
        return DesignColors.text.opacity(0.75)
    }
}

// MARK: - Preview

#Preview("Edit Period") {
    EditPeriodView(
        store: Store(
            initialState: EditPeriodFeature.State(
                cycleStartDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                cycleLength: 28,
                bleedingDays: 5,
                periodDays: [],
                periodFlowIntensity: [:]
            )
        ) {
            EditPeriodFeature()
        }
    )
}
