import ComposableArchitecture
import SwiftUI

// MARK: - Day Detail Panel

struct DayDetailPanel: View {
    @Bindable var store: StoreOf<CalendarFeature>

    private var selectedPhaseInfo: (phase: CyclePhase, cycleDay: Int, isPredicted: Bool)? {
        let info = CalendarFeature.phaseInfo(
            for: store.selectedDate,
            cycleStartDate: store.cycleStartDate,
            cycleLength: store.cycleLength,
            bleedingDays: store.bleedingDays
        )
        guard let info else { return nil }

        let isPast = store.selectedDate <= Calendar.current.startOfDay(for: Date())
        if isPast && !isSelectedPeriodDay && !info.isPredicted {
            return nil
        }

        return info
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: store.selectedDate)
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

struct PhaseBannerRow: View {
    let phase: CyclePhase?
    let cycleDay: Int?
    let dateString: String
    let isPredicted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(phase?.orbitColor.opacity(0.12) ?? DesignColors.structure.opacity(0.12))
                Text(phase?.emoji ?? "")
                    .font(.system(size: 20))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(dateString)
                    .font(.custom("Raleway-SemiBold", size: 15))
                    .foregroundStyle(DesignColors.text)

                if let phase, let day = cycleDay {
                    HStack(spacing: 6) {
                        Text("\(phase.displayName) · Day \(day)")
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundStyle(phase.orbitColor)
                        if isPredicted {
                            Text("Predicted")
                                .font(.custom("Raleway-Medium", size: 10))
                                .foregroundStyle(phase.orbitColor.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .strokeBorder(
                                            phase.orbitColor.opacity(0.4),
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                                        )
                                }
                        }
                    }
                    // Medical hormone context
                    Text(phase.medicalDescription)
                        .font(.custom("Raleway-Regular", size: 11.5))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                } else {
                    Text("Outside current cycle")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            if let phase {
                Text(phase.description)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundStyle(phase.orbitColor)
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

struct FertilityInfoCard: View {
    let level: FertilityLevel
    let isOvulationDay: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(level.color.opacity(0.15))
                Image(systemName: isOvulationDay ? "sparkle" : "leaf.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(level.color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isOvulationDay ? "Peak Fertility" : "Fertile Window")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .foregroundStyle(DesignColors.text)
                    Text(level.displayName)
                        .font(.custom("Raleway-Medium", size: 10))
                        .foregroundStyle(level.color)
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
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer()

            // Probability badge
            Text(level.probability)
                .font(.custom("Raleway-Bold", size: 13))
                .foregroundStyle(level.color)
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

// MARK: - Symptom Chips Row

struct SymptomChipsRow: View {
    let symptoms: [SymptomType]
    let phase: CyclePhase?
    let onLogTapped: () -> Void

    private var accentColor: Color { phase?.orbitColor ?? DesignColors.accentWarm }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S LOG")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .tracking(2)
                Spacer()
                Button(action: onLogTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: symptoms.isEmpty ? "plus" : "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text(symptoms.isEmpty ? "Log" : "Edit")
                            .font(.custom("Raleway-SemiBold", size: 12))
                    }
                    .foregroundStyle(accentColor)
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
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.45))
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

struct LoggedSymptomChip: View {
    let symptom: SymptomType
    let accentColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symptom.sfSymbol)
                .font(.system(size: 11, weight: .medium))
            Text(symptom.displayName)
                .font(.custom("Raleway-Medium", size: 12))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(accentColor.opacity(0.1))
                .overlay { Capsule().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5) }
        }
    }
}

// MARK: - Cycle Length Row

struct CycleLengthRow: View {
    let cycleLength: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))

            Text("Cycle Length")
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.65))

            Spacer()

            HStack(spacing: 4) {
                stepButton(icon: "minus", action: onDecrease)

                Text("\(cycleLength)d")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)
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
                .foregroundStyle(DesignColors.text.opacity(0.7))
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
