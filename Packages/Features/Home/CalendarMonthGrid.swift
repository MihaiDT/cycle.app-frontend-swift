import SwiftUI

// MARK: - Day Info

struct CalendarDayInfo {
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
    /// Predicted period day inside the late window -- show with muted "late" styling
    let isLatePredicted: Bool
    // Edit mode
    let isEditMode: Bool
    let isEditPeriodDay: Bool
}

// MARK: - Month Grid

struct MonthGridView: View, Equatable {
    let month: Date
    let cycleStartDate: Date
    let cycleLength: Int
    let bleedingDays: Int
    let loggedDays: [String: CalendarFeature.State.DayLog]
    let periodDays: Set<String>
    let predictedPeriodDays: Set<String>
    let periodFlowIntensity: [String: FlowIntensity]
    let fertileDays: [String: FertilityLevel]
    let ovulationDays: Set<String>
    let selectedDate: Date?
    let isLate: Bool
    let predictedDate: Date?
    // Edit mode
    let isEditingPeriod: Bool
    let editPeriodDays: Set<String>
    var onDaySelected: (Date) -> Void
    var onEditDayTapped: ((Date) -> Void)?

    nonisolated static func == (lhs: MonthGridView, rhs: MonthGridView) -> Bool {
        lhs.month == rhs.month
            && lhs.cycleStartDate == rhs.cycleStartDate
            && lhs.cycleLength == rhs.cycleLength
            && lhs.bleedingDays == rhs.bleedingDays
            && lhs.loggedDays == rhs.loggedDays
            && lhs.periodDays == rhs.periodDays
            && lhs.predictedPeriodDays == rhs.predictedPeriodDays
            && lhs.periodFlowIntensity == rhs.periodFlowIntensity
            && lhs.fertileDays == rhs.fertileDays
            && lhs.ovulationDays == rhs.ovulationDays
            && lhs.selectedDate == rhs.selectedDate
            && lhs.isLate == rhs.isLate
            && lhs.predictedDate == rhs.predictedDate
            && lhs.isEditingPeriod == rhs.isEditingPeriod
            && lhs.editPeriodDays == rhs.editPeriodDays
    }

    private let cal = Calendar.current
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var days: [CalendarDayInfo] {
        let cycleStart = cal.startOfDay(for: cycleStartDate)
        let today = cal.startOfDay(for: Date())

        let gridStart = mondayStartOfGrid(for: month)
        // Always 42 cells (6 rows) for consistent height — prevents LazyVStack jump glitches
        let dates = (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }

        return dates.map { date in
            let d = cal.startOfDay(for: date)
            let isCurrentMonth = cal.component(.month, from: date) == cal.component(.month, from: month)
            let key = CalendarFeature.dateKey(date)

            let isInLateWindow: Bool = {
                guard isLate, let pred = predictedDate else { return false }
                guard let diff = cal.dateComponents([.day], from: cal.startOfDay(for: pred), to: d).day else { return false }
                return diff >= -1 && diff < cycleLength
            }()
            let isServerPeriod = periodDays.contains(key)
            let isServerPredicted = predictedPeriodDays.contains(key)
            let isLatePredicted = isInLateWindow && isServerPredicted
            let info = CalendarFeature.phaseInfo(
                for: d,
                cycleStartDate: cycleStart,
                cycleLength: cycleLength,
                bleedingDays: bleedingDays
            )
            let cycleDay = info?.cycleDay
            let phase: CyclePhase? =
                isServerPeriod ? .menstrual : (info.map { $0.phase == .menstrual ? .follicular : $0.phase })
            // Suppress fertile/ovulation only within the late window, not globally
            let serverFertilityLevel = isInLateWindow ? nil : fertileDays[key]
            let isFertile = serverFertilityLevel != nil
            let isOvulation = !isInLateWindow && ovulationDays.contains(key)

            return CalendarDayInfo(
                date: date,
                dayNumber: cal.component(.day, from: date),
                isCurrentMonth: isCurrentMonth,
                isToday: d == today,
                isSelected: selectedDate.map { cal.startOfDay(for: $0) == d } ?? false,
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
                isFuture: d > today,
                isLatePredicted: isLatePredicted,
                isEditMode: isEditingPeriod,
                isEditPeriodDay: isEditingPeriod && editPeriodDays.contains(key)
            )
        }
    }

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(days, id: \.date) { info in
                Button {
                    guard info.isCurrentMonth else { return }
                    if isEditingPeriod {
                        let today = Calendar.current.startOfDay(for: Date())
                        guard info.date <= today else { return }
                        onEditDayTapped?(info.date)
                    } else {
                        guard !info.isFuture else { return }
                        onDaySelected(info.date)
                    }
                } label: {
                    CalendarDayCell(info: info)
                }
                .buttonStyle(.plain)
            }
        }
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

// MARK: - Day Cell

struct CalendarDayCell: View {
    let info: CalendarDayInfo

    var body: some View {
        if info.isEditMode {
            editModeBody
        } else {
            normalBody
        }
    }

    // MARK: - Edit Mode

    private var editModeBody: some View {
        VStack(spacing: 0) {
            ZStack {
                // Keep normal period fill only for actual server period days
                Circle()
                    .fill(fillColor)

                // Predicted period: light dashed ring
                if info.isPredicted && info.isPeriodDay && info.isCurrentMonth && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                        )
                        .foregroundStyle(CyclePhase.menstrual.orbitColor.opacity(0.35))
                }

                // Today ring
                if info.isToday && info.isCurrentMonth && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundStyle(DesignColors.accentWarm)
                }

                Text("\(info.dayNumber)")
                    .font(.raleway(
                        info.isToday || info.isUserMarkedPeriod ? "Bold" : "SemiBold",
                        size: 16,
                        relativeTo: .body
                    ))
                    .foregroundStyle(textColor)
            }
            .frame(width: 46, height: 46)

            if info.isCurrentMonth && !info.isFuture {
                Image(systemName: info.isEditPeriodDay ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: info.isEditPeriodDay ? .bold : .regular))
                    .foregroundStyle(
                        info.isEditPeriodDay
                            ? CyclePhase.menstrual.orbitColor
                            : DesignColors.structure.opacity(0.5)
                    )
                    .frame(height: 10)
            } else {
                Color.clear.frame(height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(info.isCurrentMonth ? 1 : 0)
    }


    // MARK: - Normal Mode

    private var normalBody: some View {
        VStack(spacing: 0) {
            ZStack {
                // Base fill
                Circle()
                    .fill(fillColor)

                // Ovulation day: solid amber ring
                if info.isOvulationDay && !info.isPeriodDay && info.isCurrentMonth && !info.isSelected {
                    Circle()
                        .strokeBorder(
                            CyclePhase.ovulatory.orbitColor.opacity(0.7),
                            lineWidth: 1.5
                        )
                }

                // Other fertile days: dashed amber ring
                if info.isFertile && !info.isOvulationDay && !info.isPeriodDay && info.isCurrentMonth && !info.isSelected {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                        .foregroundStyle(CyclePhase.ovulatory.orbitColor.opacity(0.5))
                }

                // Future confirmed period: dashed border (not yet passed)
                if info.isUserMarkedPeriod && info.isFuture && !info.isSelected {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                        )
                        .foregroundStyle(CyclePhase.menstrual.orbitColor.opacity(0.4))
                }

                // Predicted period: dashed border
                if info.isPredicted && info.isPeriodDay && !info.isSelected && !info.isUserMarkedPeriod && !info.isLatePredicted {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                        )
                        .foregroundStyle(CyclePhase.menstrual.orbitColor.opacity(0.4))
                }

                // Late predicted period: muted dashed border
                if info.isLatePredicted && info.isCurrentMonth && !info.isSelected {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                        )
                        .foregroundStyle(CyclePhase.menstrual.orbitColor.opacity(0.25))
                }

                // Today dashed ring
                if info.isToday && info.isCurrentMonth && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundStyle(DesignColors.accentWarm)
                }

                // Selection ring (non-period days only)
                if info.isSelected && info.isCurrentMonth && !info.isUserMarkedPeriod {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.6),
                            lineWidth: 2
                        )
                }

                Text("\(info.dayNumber)")
                    .font(.raleway(info.isSelected || info.isToday ? "Bold" : "SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(textColor)
            }
            .frame(width: 46, height: 46)

            // Today / Fertile label / Symptom dot — always 10px height for consistent layout
            if info.isToday && info.isCurrentMonth {
                Text("Today")
                    .font(.raleway("Bold", size: 8, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(height: 10)
            } else if info.isOvulationDay && !info.isPeriodDay && info.isCurrentMonth {
                Text("Fertile")
                    .font(.raleway("Bold", size: 8, relativeTo: .caption2))
                    .foregroundStyle(CyclePhase.ovulatory.orbitColor)
                    .frame(height: 10)
            } else if info.hasLog && info.isCurrentMonth {
                Circle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 4, height: 4)
                    .frame(height: 10)
            } else {
                Color.clear.frame(height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(info.isCurrentMonth ? 1 : 0)
    }

    private var fillColor: Color {
        guard info.isCurrentMonth else { return .clear }

        if info.isUserMarkedPeriod {
            if info.isFuture {
                return CyclePhase.menstrual.orbitColor.opacity(info.isSelected ? 0.35 : 0.18)
            }
            return CyclePhase.menstrual.orbitColor.opacity(info.isSelected ? 0.9 : 0.75)
        }
        if info.isLatePredicted {
            return CyclePhase.menstrual.orbitColor.opacity(0.10)
        }
        if info.isPredicted && info.isPeriodDay {
            return CyclePhase.menstrual.orbitColor.opacity(info.isSelected ? 0.35 : 0.18)
        }
        if info.isOvulationDay && !info.isPeriodDay {
            return CyclePhase.ovulatory.orbitColor.opacity(info.isSelected ? 0.6 : 0.45)
        }
        if info.isFertile && !info.isPeriodDay {
            return CyclePhase.ovulatory.orbitColor.opacity(info.isSelected ? 0.5 : 0.35)
        }
        return .clear
    }

    private var textColor: Color {
        guard info.isCurrentMonth else { return DesignColors.textPlaceholder.opacity(0.35) }
        if info.isUserMarkedPeriod && !info.isFuture { return .white }
        if info.isSelected { return DesignColors.text }
        return DesignColors.text.opacity(0.75)
    }
}
