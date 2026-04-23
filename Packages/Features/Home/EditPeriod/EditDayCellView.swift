import ComposableArchitecture
import SwiftUI

// MARK: - Edit Day Cell View

struct EditDayCellView: View {
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
