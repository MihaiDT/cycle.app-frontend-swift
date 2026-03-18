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
        public var isSaving: Bool = false
        public var isSaved: Bool = false
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
            periodDays: Set<String>,
            periodFlowIntensity: [String: FlowIntensity]
        ) {
            let today = Calendar.current.startOfDay(for: Date())
            var comps = Calendar.current.dateComponents([.year, .month], from: today)
            comps.day = 1
            self.initialMonth = Calendar.current.date(from: comps) ?? today
            self.periodDays = periodDays
            self.periodFlowIntensity = periodFlowIntensity
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
        case dayTapped(Date)
        case flowIntensityChanged(String, FlowIntensity)
        case saveTapped
        case saveDone(
            periodDays: Set<String>,
            periodFlowIntensity: [String: FlowIntensity]
        )
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case didSave(
                periodDays: Set<String>,
                periodFlowIntensity: [String: FlowIntensity]
            )
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
                              cal.startOfDay(for: d) > today
                        else { continue }
                        let k = Self.dateKey(d)
                        if state.periodDays.contains(k) {
                            state.periodDays.remove(k)
                            state.periodFlowIntensity.removeValue(forKey: k)
                        } else {
                            break
                        }
                    }
                    if state.selectedPeriodDay == key {
                        state.selectedPeriodDay = nil
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
                        // Auto-fill 5 days (tapped + 4 after)
                        for i in 0..<5 {
                            guard let d = cal.date(byAdding: .day, value: i, to: date)
                            else { break }
                            let k = Self.dateKey(d)
                            state.periodDays.insert(k)
                            state.periodFlowIntensity[k] = .medium
                        }
                    }
                    state.selectedPeriodDay = key
                }
                return .none

            case .flowIntensityChanged(let key, let intensity):
                state.periodFlowIntensity[key] = intensity
                return .none

            case .saveTapped:
                state.isSaving = true
                state.isSaved = false
                let periodDays = state.periodDays
                let flowIntensity = state.periodFlowIntensity
                // Compute earliest start date and bleeding day count
                let sortedDays = periodDays.sorted()
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                let startDate = sortedDays.first.flatMap { fmt.date(from: $0) } ?? Date()
                let bleedingCount = periodDays.count
                return .run { [menstrualClient, sessionClient] send in
                    if let token = await sessionClient.getAccessToken() {
                        let request = ConfirmPeriodRequest(
                            actualStartDate: startDate,
                            bleedingDays: bleedingCount
                        )
                        try? await menstrualClient.confirmPeriod(token, request)
                    }
                    await send(.saveDone(
                        periodDays: periodDays,
                        periodFlowIntensity: flowIntensity
                    ), animation: .easeInOut(duration: 0.3))
                }

            case .saveDone(let periodDays, let flowIntensity):
                state.isSaving = false
                state.isSaved = true
                return .run { send in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.delegate(.didSave(
                        periodDays: periodDays,
                        periodFlowIntensity: flowIntensity
                    )))
                }

            case .cancelTapped:
                return .run { _ in await dismiss() }

            case .binding, .delegate:
                return .none
            }
        }
    }

    static func dateKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

// MARK: - EditPeriodView

public struct EditPeriodView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<EditPeriodFeature>

    private let cal = Calendar.current

    // 24 months back → 3 months forward
    private var allMonths: [Date] {
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.year, .month], from: today)
        comps.day = 1
        let thisMonth = cal.date(from: comps) ?? today
        return (-24...3).compactMap { cal.date(byAdding: .month, value: $0, to: thisMonth) }
    }

    private func monthID(_ month: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: month)
    }

    public init(store: StoreOf<EditPeriodFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                editHeader

                weekdayLabels
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                Divider()
                    .overlay(DesignColors.structure.opacity(0.15))

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(allMonths, id: \.self) { month in
                                Section {
                                    monthGrid(for: month)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                } header: {
                                    monthSectionHeader(month)
                                }
                                .id(monthID(month))
                            }
                            Color.clear.frame(height: 140)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(monthID(store.initialMonth), anchor: .top)
                        }
                    }
                }
            }

            // Bottom overlay: flow selector + save button
            VStack(spacing: 0) {
                if let selectedKey = store.selectedPeriodDay,
                   store.periodDays.contains(selectedKey) {
                    flowIntensitySelector(for: selectedKey)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if store.hasChanges || store.isSaving || store.isSaved {
                    saveButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.selectedPeriodDay)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.hasChanges)
        }
        .enableInjection()
    }

    // MARK: - Header

    private var editHeader: some View {
        HStack(spacing: 12) {
            Button { store.send(.cancelTapped) } label: {
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
                    .font(.custom("Raleway-Bold", size: 24))
                    .foregroundColor(DesignColors.text)

                Text("Tap days to mark or remove")
                    .font(.custom("Raleway-Regular", size: 13))
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
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Section

    private func monthSectionHeader(_ month: Date) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let title = fmt.string(from: month)

        return HStack {
            Text(title)
                .font(.custom("Raleway-Bold", size: 16))
                .foregroundColor(DesignColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(DesignColors.background)
    }

    // MARK: - Month Grid

    private func monthGrid(for month: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        let days = gridDays(for: month)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, info in
                editDayCell(info: info)
                    .onTapGesture {
                        guard info.isCurrentMonth else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.send(.dayTapped(info.date), animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }
            }
        }
    }

    private struct EditDayInfo {
        let date: Date
        let dayNumber: Int
        let isCurrentMonth: Bool
        let isToday: Bool
        let isPeriodDay: Bool
        let isFuture: Bool
        let flowIntensity: FlowIntensity?
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
                date: date,
                dayNumber: cal.component(.day, from: date),
                isCurrentMonth: isCurrentMonth,
                isToday: d == today,
                isPeriodDay: store.periodDays.contains(key),
                isFuture: d > today,
                flowIntensity: store.periodFlowIntensity[key]
            )
        }
    }

    private func editDayCell(info: EditDayInfo) -> some View {
        let isSelected = store.selectedPeriodDay == EditPeriodFeature.dateKey(info.date)

        return VStack(spacing: 0) {
            ZStack {
                if info.isPeriodDay && info.isCurrentMonth {
                    if info.isFuture {
                        // Future period days: dashed border
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
                        // Past/today period days: solid fill
                        Circle()
                            .fill(CyclePhase.menstrual.orbitColor.opacity(isSelected ? 0.9 : 0.75))
                            .overlay {
                                if isSelected {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                }
                            }
                    }
                }

                if info.isToday && !info.isPeriodDay {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundColor(DesignColors.accentWarm)
                }

                Text("\(info.dayNumber)")
                    .font(.custom(
                        info.isPeriodDay || info.isToday ? "Raleway-Bold" : "Raleway-SemiBold",
                        size: 14
                    ))
                    .foregroundColor(dayTextColor(info))
                    .offset(y: info.isPeriodDay && info.isCurrentMonth ? -3 : 0)

                if info.isPeriodDay && info.isCurrentMonth {
                    editDropletIndicator(intensity: info.flowIntensity)
                        .offset(y: 10)
                }
            }
            .frame(width: 40, height: 40)
            .shadow(
                color: info.isPeriodDay
                    ? CyclePhase.menstrual.glowColor.opacity(0.25)
                    : .clear,
                radius: 6, x: 0, y: 2
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: info.isPeriodDay)

            if info.isToday && info.isCurrentMonth {
                Text("Today")
                    .font(.custom("Raleway-Bold", size: 8))
                    .foregroundColor(DesignColors.accentWarm)
                    .frame(height: 10)
            } else {
                Color.clear.frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(info.isCurrentMonth ? (info.isFuture && !info.isPeriodDay ? 0.35 : 1) : 0.18)
    }

    private func dayTextColor(_ info: EditDayInfo) -> Color {
        guard info.isCurrentMonth else { return DesignColors.textPlaceholder.opacity(0.35) }
        if info.isPeriodDay { return .white }
        if info.isFuture { return DesignColors.textSecondary.opacity(0.4) }
        if info.isToday { return DesignColors.text }
        return DesignColors.text.opacity(0.75)
    }

    private func editDropletIndicator(intensity: FlowIntensity?) -> some View {
        let resolved = intensity ?? .medium
        return Group {
            if resolved == .spotting {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 5, height: 5)
            } else {
                HStack(spacing: 1) {
                    ForEach(0..<resolved.dropletCount, id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 7, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
            }
        }
    }

    // MARK: - Flow Intensity Selector

    private func flowIntensitySelector(for key: String) -> some View {
        let current = store.periodFlowIntensity[key] ?? .medium

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CyclePhase.menstrual.orbitColor)

                Text("FLOW INTENSITY")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.65))
                    .tracking(2)

                Spacer()

                Text(dateLabel(for: key))
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundColor(DesignColors.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(FlowIntensity.allCases, id: \.self) { intensity in
                    Button {
                        store.send(
                            .flowIntensityChanged(key, intensity),
                            animation: .spring(response: 0.25, dampingFraction: 0.8)
                        )
                    } label: {
                        flowOption(intensity: intensity, isSelected: current == intensity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    CyclePhase.menstrual.orbitColor.opacity(0.35),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }

    private func flowOption(intensity: FlowIntensity, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if intensity == .spotting {
                    Circle()
                        .fill(isSelected ? Color.white : CyclePhase.menstrual.orbitColor.opacity(0.5))
                        .frame(width: 5, height: 5)
                } else {
                    ForEach(0..<intensity.dropletCount, id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(isSelected ? .white : CyclePhase.menstrual.orbitColor.opacity(0.5))
                }
            }
            .frame(height: 18)

            Text(intensity.rawValue.capitalized)
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundColor(isSelected ? .white : DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? CyclePhase.menstrual.orbitColor
                        : DesignColors.structure.opacity(0.12)
                )
                .overlay {
                    if !isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(DesignColors.structure.opacity(0.3), lineWidth: 0.5)
                    }
                }
                .shadow(
                    color: isSelected ? CyclePhase.menstrual.glowColor.opacity(0.3) : .clear,
                    radius: 6, x: 0, y: 2
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
                HStack(spacing: 8) {
                    if store.isSaving {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else if store.isSaved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(store.isSaved ? "Saved!" : store.isSaving ? "Saving..." : "Save Period")
                        .font(.custom("Raleway-Bold", size: 17))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: store.isSaved
                                    ? [Color.green, Color.green]
                                    : [CyclePhase.menstrual.orbitColor, CyclePhase.menstrual.orbitColor.opacity(0.8)],
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
                        .shadow(color: (store.isSaved ? Color.green : CyclePhase.menstrual.glowColor).opacity(0.4), radius: 12, x: 0, y: 4)
                }
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving || store.isSaved)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(DesignColors.background)
    }

    // MARK: - Helpers

    private func dateLabel(for key: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: key) else { return key }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
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
