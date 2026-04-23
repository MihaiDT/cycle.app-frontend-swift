import ComposableArchitecture
import SwiftUI

// MARK: - CalendarView

public struct CalendarView: View {
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
            JourneyAnimatedBackground()

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
        .padding(.horizontal, AppLayout.screenHorizontal)
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
        // "Log Symptoms" lives on the Home tab under the hero for now —
        // keep only Edit Period here so the calendar bottom bar stays
        // focused on period editing.
        HStack(spacing: 12) {
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

