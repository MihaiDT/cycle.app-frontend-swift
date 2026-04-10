import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - CalendarView

public struct CalendarView: View {
    @ObserveInjection var inject
    @Bindable public var store: StoreOf<CalendarFeature>

    public init(store: StoreOf<CalendarFeature>) {
        self.store = store
    }

    @State private var detailSheetDetent: PresentationDetent = .medium
    @State private var isShowingDayDetail: Bool = false
    @State private var viewMode: CalendarViewMode = .month
    @State private var yearViewCreated: Bool = false
    @State private var scrollTarget: String?

    enum CalendarViewMode: String, CaseIterable {
        case month = "Month"
        case year = "Year"
    }

    private let cal = Calendar.current

    static let months: [Date] = {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        let current = cal.date(from: comps) ?? Date()
        return (-24...12).compactMap { cal.date(byAdding: .month, value: $0, to: current) }
    }()

    static let monthIdFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt
    }()

    private func monthId(_ date: Date) -> String {
        Self.monthIdFormatter.string(from: date)
    }

    public var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                FeedTopBar(store: store, viewMode: $viewMode)

                    ZStack {
                        // Month view
                        VStack(spacing: 0) {
                            WeekdayLabelsRow()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)

                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Self.months, id: \.self) { month in
                                        VStack(spacing: 0) {
                                            MonthSectionHeader(date: month)
                                            MonthGridView(
                                                month: month,
                                                cycleStartDate: store.cycleStartDate,
                                                cycleLength: store.cycleLength,
                                                bleedingDays: store.bleedingDays,
                                                loggedDays: store.loggedDays,
                                                periodDays: store.periodDays,
                                                predictedPeriodDays: store.predictedPeriodDays,
                                                periodFlowIntensity: store.periodFlowIntensity,
                                                fertileDays: store.fertileDays,
                                                ovulationDays: store.ovulationDays,
                                                selectedDate: store.selectedDate,
                                                isLate: store.menstrualStatus?.nextPrediction?.isLate == true,
                                                predictedDate: store.menstrualStatus?.nextPrediction?.predictedDate,
                                                isEditingPeriod: store.isEditingPeriod,
                                                editPeriodDays: store.editPeriodDays,
                                                onDaySelected: { date in
                                                    store.send(.daySelected(date), animation: .spring(response: 0.3, dampingFraction: 0.8))
                                                },
                                                onEditDayTapped: { date in
                                                    store.send(.editPeriodDayTapped(date), animation: .spring(response: 0.3, dampingFraction: 0.7))
                                                }
                                            )
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 20)
                                        }
                                    }
                                }
                                .padding(.bottom, 120)
                            }
                        }
                        .background(DesignColors.background)
                        .opacity(viewMode == .month ? 1 : 0)
                        .allowsHitTesting(viewMode == .month)

                        // Year view — deferred until first tap
                        if yearViewCreated || viewMode == .year {
                            YearOverviewView(
                                periodDays: store.periodDays,
                                predictedPeriodDays: store.predictedPeriodDays,
                                fertileDays: store.fertileDays,
                                ovulationDays: store.ovulationDays,
                                cycleLength: store.cycleLength,
                                menstrualStatus: store.menstrualStatus,
                                onMonthTapped: { [self] month in
                                    scrollTarget = monthId(month)
                                    store.send(.binding(.set(\.displayedMonth, month)))
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                                            viewMode = .month
                                        }
                                    }
                                }
                            )
                            .background(DesignColors.background)
                            .opacity(viewMode == .year ? 1 : 0)
                            .allowsHitTesting(viewMode == .year)
                            .onAppear { yearViewCreated = true }
                        }
                    }
            }

            // Prediction banner
            if store.isEditingPeriod && (store.isUpdatingPredictions || store.predictionsDone) {
                VStack {
                    EditPeriodPredictionBanner(
                        isUpdating: store.isUpdatingPredictions,
                        isDone: store.predictionsDone
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 80)
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.isUpdatingPredictions)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.predictionsDone)
            }

            // Floating buttons
            VStack {
                Spacer()

                if viewMode == .month {
                    if store.isEditingPeriod && !store.isUpdatingPredictions && !store.predictionsDone {
                        editPeriodBottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !store.isEditingPeriod {
                        normalBottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.isEditingPeriod)
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
        .sheet(
            isPresented: $store.isShowingSymptomSheet,
            onDismiss: {
                store.send(.symptomSheetDismissed)
            }
        ) {
            SymptomLoggingSheet(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusXL)
                .presentationBackground(DesignColors.background)
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(isPresented: Binding(
            get: { store.showAriaPrompt },
            set: { if !$0 { store.send(.ariaPromptDismissed) } }
        )) {
            AriaRecapSheet(
                monthName: "",
                message: store.ariaPromptMessage,
                buttonTitle: "Talk to Aria",
                onAction: { store.send(.ariaPromptTalkTapped) }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppLayout.cornerRadiusL)
            .presentationBackground(DesignColors.background)
        }
        .enableInjection()
    }

    // MARK: - Normal Bottom Bar

    private var normalBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.logSymptomsTapped, animation: .spring(response: 0.4, dampingFraction: 0.88))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Log Symptoms")
                        .font(.custom("Raleway-SemiBold", size: 13))
                }
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().strokeBorder(
                                DesignColors.accentWarm.opacity(0.45),
                                lineWidth: 1
                            )
                        }
                        .shadow(color: DesignColors.accentWarm.opacity(0.25), radius: 10, x: 0, y: 4)
                }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.editPeriodToggled, animation: .spring(response: 0.35, dampingFraction: 0.85))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Edit Period")
                        .font(.custom("Raleway-SemiBold", size: 13))
                }
                .foregroundStyle(CyclePhase.menstrual.orbitColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().strokeBorder(
                                CyclePhase.menstrual.orbitColor.opacity(0.4),
                                lineWidth: 1
                            )
                        }
                        .shadow(color: CyclePhase.menstrual.orbitColor.opacity(0.2), radius: 10, x: 0, y: 4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Edit Period Bottom Bar

    private var editPeriodBottomBar: some View {
        HStack(spacing: 12) {
            if store.hasEditPeriodChanges && !store.isUpdatingPredictions {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.send(.editPeriodSaveTapped, animation: .easeInOut(duration: 0.3))
                } label: {
                    Text("Save Period")
                        .font(.custom("Raleway-Bold", size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
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
                                .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.editPeriodToggled, animation: .spring(response: 0.35, dampingFraction: 0.85))
            } label: {
                Text(store.hasEditPeriodChanges ? "Cancel" : "Done")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Edit Period Prediction Banner

struct EditPeriodPredictionBanner: View {
    let isUpdating: Bool
    let isDone: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isDone {
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
                        .foregroundStyle(.white)
                } else {
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
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())

                Text(isDone ? "Your calendar is up to date" : "Analyzing your cycle patterns...")
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundStyle(DesignColors.textSecondary)
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
        .onAppear {
            if !isDone {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
        }
    }
}

// MARK: - Feed Top Bar

struct FeedTopBar: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @Binding var viewMode: CalendarView.CalendarViewMode
    @Namespace private var pillAnimation

    var body: some View {
        HStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if store.isEditingPeriod {
                    store.send(.editPeriodToggled, animation: .spring(response: 0.35, dampingFraction: 0.85))
                } else {
                    store.send(.dismissTapped)
                }
            } label: {
                Image(systemName: store.isEditingPeriod ? "chevron.left" : "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay { Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5) }
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            if store.isEditingPeriod {
                Text("Tap days to mark your period")
                    .font(.custom("Raleway-Medium", size: 14))
                    .foregroundStyle(DesignColors.textSecondary)
                    .transition(.opacity)
            } else {
                HStack(spacing: 0) {
                    ForEach(CalendarView.CalendarViewMode.allCases, id: \.self) { mode in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewMode = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.custom("Raleway-SemiBold", size: 13))
                                .foregroundStyle(viewMode == mode ? DesignColors.text : DesignColors.textSecondary.opacity(0.5))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background {
                                    if viewMode == mode {
                                        Capsule()
                                            .fill(Color.white.opacity(0.12))
                                            .matchedGeometryEffect(id: "pill", in: pillAnimation)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5) }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.isEditingPeriod)
    }
}

// MARK: - Month Section Header

struct MonthSectionHeader: View {
    let date: Date

    private static let monthOnly: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM"
        return fmt
    }()

    private static let monthYear: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt
    }()

    private var isCurrentYear: Bool {
        Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignColors.divider)
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            Text(isCurrentYear ? Self.monthOnly.string(from: date) : Self.monthYear.string(from: date))
                .font(.custom("Raleway-Bold", size: 16))
                .foregroundStyle(DesignColors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Weekday Labels

struct WeekdayLabelsRow: View {
    private let labels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
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
