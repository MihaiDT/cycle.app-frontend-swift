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

    @State private var scrollTarget: String?
    @State private var isCurrentMonthVisible: Bool = true
    @State private var scrollTrigger: Int = 0

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

    nonisolated(unsafe) static let monthIdFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt
    }()

    private func monthId(_ date: Date) -> String {
        Self.monthIdFormatter.string(from: date)
    }

    public var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ZStack(alignment: .top) {
                    ZStack {
                        // Month view — UIKit native scroll
                        VStack(spacing: 0) {
                            // Spacer for header + weekday row
                            Color.clear.frame(height: 80)

                            CalendarTableView(
                                months: Self.months,
                                periodDays: store.periodDays,
                                predictedPeriodDays: store.predictedPeriodDays,
                                fertileDays: store.fertileDays,
                                ovulationDays: store.ovulationDays,
                                selectedDate: store.selectedDate,
                                isLate: store.menstrualStatus?.nextPrediction?.isLate == true,
                                predictedDate: store.menstrualStatus?.nextPrediction?.predictedDate,
                                cycleLength: store.cycleLength,
                                loggedDays: store.loggedDays,
                                isEditingPeriod: store.isEditingPeriod,
                                editPeriodDays: store.editPeriodDays,
                                onDaySelected: { date in
                                    store.send(.daySelected(date), animation: .spring(response: 0.3, dampingFraction: 0.8))
                                },
                                onEditDayTapped: { date in
                                    store.send(.editPeriodDayTapped(date), animation: .spring(response: 0.3, dampingFraction: 0.7))
                                },
                                initialMonth: store.displayedMonth,
                                scrollTrigger: scrollTrigger,
                                scrollTargetMonth: store.displayedMonth,
                                onCurrentMonthVisibilityChanged: { visible in
                                    if visible != isCurrentMonthVisible {
                                        isCurrentMonthVisible = visible
                                    }
                                }
                            )
                            .ignoresSafeArea(edges: .bottom)
                        }
                        .background(Color.white)
                        .opacity(viewMode == .month ? 1 : 0)
                        .blur(radius: viewMode == .month ? 0 : 6)
                        .allowsHitTesting(viewMode == .month)
                        .animation(.easeOut(duration: 0.3), value: viewMode)

                        // Year view — UICollectionView + CoreGraphics
                        if viewMode == .year {
                            CalendarYearCollectionView(
                                periodDays: store.periodDays,
                                predictedPeriodDays: store.predictedPeriodDays,
                                fertileDays: store.fertileDays,
                                ovulationDays: store.ovulationDays,
                                cycleLength: store.cycleLength,
                                menstrualStatus: store.menstrualStatus,
                                onMonthTapped: { [self] month in
                                    store.send(.binding(.set(\.displayedMonth, month)))
                                    scrollTrigger += 1
                                },
                                onZoomCompleted: { [self] in
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        viewMode = .month
                                    }
                                }
                            )
                            .background(Color.white)
                            .ignoresSafeArea(edges: .bottom)
                            .transition(
                                .opacity.combined(with: .modifier(
                                    active: BlurModifier(radius: 6),
                                    identity: BlurModifier(radius: 0)
                                ))
                                .animation(.easeOut(duration: 0.3))
                            )
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
                .animation(.appBalanced, value: store.isUpdatingPredictions)
                .animation(.appBalanced, value: store.predictionsDone)
            }

            // Calendar loading indicators.
            // - Full-screen centered spinner only on the very first fetch (no data yet).
            // - Subtle top pill for idempotent re-fetches so existing UI is preserved.
            // - Skipped entirely during edit-period flow (dedicated banner already shown).
            if store.isLoadingCalendar && !store.isEditingPeriod {
                if store.periodDays.isEmpty && store.fertileDays.isEmpty && store.ovulationDays.isEmpty {
                    ZStack {
                        Color.white.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(DesignColors.accentWarm)
                                .scaleEffect(1.15)
                            Text("Loading calendar…")
                                .font(.raleway("Medium", size: 13, relativeTo: .caption))
                                .foregroundStyle(DesignColors.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Loading calendar")
                    .accessibilityAddTraits(.updatesFrequently)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                } else {
                    VStack {
                        calendarRefreshPill
                            .padding(.top, 88)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }

            // Empty state — no periods ever logged. Only shown when calendar
            // has finished loading (`hasPreloaded` kicked off the initial load
            // and `isLoadingCalendar` is back to false) AND the user isn't
            // actively editing. Guards against a single-frame flicker on cold
            // start before `.loadCalendar` fires.
            if viewMode == .month
                && store.hasPreloaded
                && !store.isLoadingCalendar
                && !store.isEditingPeriod
                && store.periodDays.isEmpty
                && store.predictedPeriodDays.isEmpty
            {
                CalendarEmptyStateCard(onLogTapped: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.send(.editPeriodToggled, animation: .appBalanced)
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(true)
            }

            // Header overlay — pinned to top, content scrolls behind blur
            VStack(spacing: 0) {
                FeedTopBar(store: store, viewMode: $viewMode, isCurrentMonthVisible: isCurrentMonthVisible, onTodayTapped: {
                    var c = Calendar.current.dateComponents([.year, .month], from: Date())
                    c.day = 1
                    let today = Calendar.current.date(from: c) ?? Date()
                    store.send(.binding(.set(\.displayedMonth, today)))
                    scrollTrigger += 1
                    if viewMode == .year {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewMode = .month
                        }
                    }
                })

                if viewMode == .month {
                    WeekdayLabelsRow()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
            .background(.ultraThinMaterial)
            .frame(maxHeight: .infinity, alignment: .top)

            // Floating buttons
            VStack {
                Spacer()

                if viewMode == .month {
                    if store.isEditingPeriod && !store.isUpdatingPredictions && !store.predictionsDone {
                        editPeriodBottomBar
                            .transition(.opacity)
                    } else if !store.isEditingPeriod {
                        normalBottomBar
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isEditingPeriod)
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoadingCalendar)
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
                .presentationBackground(.white)
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

    // MARK: - Calendar Refresh Pill (subtle top indicator for idempotent reloads)

    private var calendarRefreshPill: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(DesignColors.accentWarm)
            Text("Refreshing calendar…")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Refreshing calendar")
    }

    // MARK: - Normal Bottom Bar

    private var normalBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.logSymptomsTapped, animation: .appBalanced)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("Log Symptoms")
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                }
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background {
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(2)
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .shadow(color: DesignColors.accentWarm.opacity(0.12), radius: 8, x: 0, y: 3)
                }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.editPeriodToggled, animation: .appBalanced)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Edit Period")
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
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
                        .font(.raleway("Bold", size: 15, relativeTo: .body))
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
                .transition(.opacity)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.editPeriodToggled, animation: .appBalanced)
            } label: {
                Text(store.hasEditPeriodChanges ? "Cancel" : "Done")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
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
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())

                Text(isDone ? "Your calendar is up to date" : "Analyzing your cycle patterns...")
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
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
    var isCurrentMonthVisible: Bool
    var onTodayTapped: () -> Void


    var body: some View {
        HStack(spacing: 0) {
            // Left: X / Back
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if store.isEditingPeriod {
                    store.send(.editPeriodToggled, animation: .appBalanced)
                } else {
                    store.send(.dismissTapped)
                }
            } label: {
                Image(systemName: store.isEditingPeriod ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 44, height: 44)
                    .background {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.9), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .padding(2)
                                .offset(y: -2)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: Month/Year toggle or edit hint
            if store.isEditingPeriod {
                Text("Tap days to mark your period")
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .transition(.opacity)
            } else {
                Picker("", selection: Binding(
                    get: { viewMode },
                    set: { newValue in
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewMode = newValue
                        }
                    }
                )) {
                    ForEach(CalendarView.CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .transition(.opacity)
            }

            Spacer()

            // Right: Today button — fixed width container so Month/Year stays centered
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTodayTapped()
            } label: {
                Text("Today")
                    .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)
            .opacity(store.isEditingPeriod || (viewMode == .month && isCurrentMonthVisible) ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isCurrentMonthVisible)
            .allowsHitTesting(!store.isEditingPeriod && !(viewMode == .month && isCurrentMonthVisible))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: store.isEditingPeriod)
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
                .font(.raleway("Bold", size: 16, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Blur Modifier

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

// MARK: - Weekday Labels

struct WeekdayLabelsRow: View {
    private let labels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.raleway("Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Calendar Empty State

/// Shown when the calendar grid has no period data yet. Sits centered on the
/// grid with a subtle warm card inviting the user to log their first period.
struct CalendarEmptyStateCard: View {
    var onLogTapped: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(DesignColors.accentWarm.opacity(0.7))
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("No cycle data yet")
                        .font(.raleway("Bold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                        .multilineTextAlignment(.center)

                    Text("Log your first period to see predictions,\nfertile windows and your phase today.")
                        .font(.raleway("Regular", size: 13, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Button {
                    onLogTapped()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Log my first period")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: DesignColors.accentWarm.opacity(0.35), radius: 10, x: 0, y: 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens edit-period mode to mark your first period days")
                .padding(.top, 2)
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(DesignColors.accent.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(DesignColors.accentWarm.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
            }
            .padding(.horizontal, 28)

            Spacer()
            // Leave room for the floating "Log Symptoms / Edit Period" bar
            // so the empty-state card doesn't collide with it.
            Color.clear.frame(height: 80)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cycle data yet. Log your first period to see predictions, fertile windows, and your phase today.")
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
