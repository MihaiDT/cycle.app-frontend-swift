import ComposableArchitecture
import SwiftUI


// MARK: - EditPeriodView

public struct EditPeriodView: View {
    @Bindable var store: StoreOf<EditPeriodFeature>
    @State private var appeared = false

    private let cal = Calendar.current

    // 12 months back → 1 month forward (computed once)
    private static let allMonthsCache: [Date] = {
        let cal = Calendar.current
        let thisMonth = cal.startOfMonth(for: Date())
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
        .animation(.appSnappy, value: appeared)
        .onAppear {
            store.send(.appeared)
            appeared = true
        }
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

    struct EditDayInfo: Equatable, Identifiable {
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
        let firstOfMonth = cal.startOfMonth(for: month)
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

