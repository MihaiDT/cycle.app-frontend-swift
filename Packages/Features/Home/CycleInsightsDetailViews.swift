import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Tabbed Detail Screen

extension CycleInsightsView {
    func detailTint(_ section: CycleInsightsFeature.State.DetailSection) -> Color {
        switch section {
        case .rhythm: return DesignColors.accentSecondary
        case .phases: return phase?.orbitColor ?? DesignColors.accentWarm
        case .body: return CyclePhase.menstrual.orbitColor
        }
    }

    @ViewBuilder
    func detailScreen(for section: CycleInsightsFeature.State.DetailSection) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button { store.send(.closeDetail) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.custom("Raleway-Medium", size: 17, relativeTo: .body))
                    }
                    .foregroundStyle(DesignColors.text)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tab bar
            detailTabBar(selected: section)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Content
                    switch section {
                    case .rhythm: cycleLengthDetail
                    case .phases: phaseGuideDetail
                    case .body: bleedingDetail
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.top, 24)
            }
        }
    }

    // MARK: - Detail Tab Bar

    @ViewBuilder
    func detailTabBar(selected: CycleInsightsFeature.State.DetailSection) -> some View {
        let tabs: [(CycleInsightsFeature.State.DetailSection, String, String)] = [
            (.rhythm, "Rhythm", "waveform.path"),
            (.phases, "Phases", "moon.stars"),
            (.body, "Body", "heart.fill"),
        ]

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.0) { tab in
                    let isSelected = selected == tab.0
                    let tint = detailTint(tab.0)

                    Button {
                        withAnimation(.appBalanced) {
                            _ = store.send(.openDetail(tab.0))
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: tab.2)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.1)
                                .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .subheadline))
                        }
                        .foregroundStyle(isSelected ? .white : DesignColors.text.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [tint, tint.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "detailActiveTab", in: tabNamespace)
                                    .shadow(color: tint.opacity(0.25), radius: 8, x: 0, y: 3)
                            } else {
                                Capsule()
                                    .fill(DesignColors.structure.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
    }

    // MARK: Cycle Length Detail

    @ViewBuilder
    var cycleLengthDetail: some View {
        let history = (store.stats?.cycleLength.history ?? []).filter { $0.length > 0 }
        let avg = store.stats?.cycleLength.average ?? 0
        let stdDev = store.stats?.cycleLength.stdDev ?? 0
        let avgInt = Int(avg)
        let avgBleeding = history.isEmpty ? 5 : history.map(\.bleeding).reduce(0, +) / history.count

        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 36) {

                // 1. Hero stat card (with trend)
                cycleLengthHeroCard(avg: avg, stdDev: stdDev)

                // 2. Chart (interactive, normal/atypical, explore button)
                CycleLengthChart(history: history, average: avg) {
                    store.send(.openCycleStory)
                }
                .frame(height: 320)

                // 3. Phase breakdown
                phaseBreakdownBar(cycleLength: avgInt, bleedingDays: avgBleeding)
            }
            .padding(.horizontal, 24)
        } else {
            lockedPlaceholder(message: "Your rhythm reveals itself after 2 complete cycles")
                .padding(.horizontal, 24)
        }
    }

    // MARK: Cycle Length Hero Card

    @ViewBuilder
    func cycleLengthHeroCard(avg: Double, stdDev: Double) -> some View {
        let rhythm = rhythmPersonality(avg: avg, stdDev: stdDev)
        let trend = trendLabel(stdDev: stdDev, history: store.stats?.cycleLength.history ?? [])

        VStack(alignment: .leading, spacing: 14) {
            Text("Average cycle length")
                .font(.custom("Raleway-Bold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)

            HStack(spacing: 16) {
            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(avg))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignColors.text)
                Text("days")
                    .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            // Divider
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(rhythm.colors[0].opacity(0.3))
                .frame(width: 2, height: 32)

            // Rhythm + trend
            VStack(alignment: .leading, spacing: 4) {
                Text(rhythm.title)
                    .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(rhythm.colors[0])

                Text(trend)
                    .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignColors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
    }

    // MARK: Phase Breakdown Bar

    @ViewBuilder
    func phaseBreakdownBar(cycleLength: Int, bleedingDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your phase breakdown")
                .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 3) {
                    ForEach(CyclePhase.biologicalPhases, id: \.self) { p in
                        let range = p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
                        let days = range.upperBound - range.lowerBound + 1
                        let fraction = CGFloat(days) / CGFloat(cycleLength)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(p.orbitColor)
                            .frame(width: max(fraction * w - 3, 6))
                    }
                }
            }
            .frame(height: 20)

            HStack(spacing: 0) {
                ForEach(CyclePhase.biologicalPhases, id: \.self) { p in
                    let range = p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
                    let days = range.upperBound - range.lowerBound + 1

                    VStack(spacing: 5) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(p.orbitColor)
                                .frame(width: 9, height: 9)
                            Text("\(days)d")
                                .font(.custom("Raleway-Bold", size: 15, relativeTo: .subheadline))
                                .foregroundStyle(DesignColors.text)
                        }
                        Text(p.description)
                            .font(.custom("Raleway-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.structure.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: Cycle Length Helpers

    struct RhythmPersonality {
        let title: String
        let icon: String
        let description: String
        let colors: [Color]
    }

    func rhythmPersonality(avg: Double, stdDev: Double) -> RhythmPersonality {
        if stdDev >= 5 {
            return RhythmPersonality(
                title: "Dynamic Rhythm",
                icon: "wind",
                description: "Your cycle adapts and shifts. Variable cycles often reflect your body's sensitivity to stress, sleep, travel, or lifestyle changes — not a problem, just information. Your body is responsive, not broken.",
                colors: [DesignColors.accentWarm, DesignColors.accentWarm.opacity(0.6)]
            )
        }
        switch Int(avg) {
        case ...24:
            return RhythmPersonality(
                title: "Quick Rhythm",
                icon: "hare",
                description: "Shorter cycles mean you move through phases faster — your follicular window is compressed, so your bursts of rising energy are intense but brief. You may ovulate earlier than textbooks suggest.",
                colors: [CyclePhase.ovulatory.orbitColor, CyclePhase.follicular.orbitColor.opacity(0.7)]
            )
        case 25...28:
            return RhythmPersonality(
                title: "Steady Rhythm",
                icon: "metronome",
                description: "Your \(Int(avg))-day cycle sits right in the textbook sweet spot — but there's nothing generic about it. Your estrogen peaks hit on schedule, your luteal phase holds steady, and your body transitions between phases without the hormonal whiplash others experience. That reliability is rare, and it means you can trust your energy patterns week to week.",
                colors: [DesignColors.accentSecondary, DesignColors.accent.opacity(0.7)]
            )
        case 29...32:
            return RhythmPersonality(
                title: "Long Wave",
                icon: "water.waves",
                description: "Longer cycles mean an extended follicular phase — more days of rising creativity, confidence, and verbal sharpness before ovulation. Your building phase is your superpower.",
                colors: [DesignColors.accent, DesignColors.accentSecondary.opacity(0.6)]
            )
        default:
            return RhythmPersonality(
                title: "Deep Rhythm",
                icon: "tortoise",
                description: "Your body takes its time. Cycles over 32 days often mean a longer follicular phase with a delayed ovulation. You may experience extended periods of rising energy and gradual hormonal shifts.",
                colors: [CyclePhase.luteal.orbitColor, DesignColors.accent.opacity(0.5)]
            )
        }
    }

    // MARK: Regularity Detail

    // MARK: Bleeding Detail

    @ViewBuilder
    var bleedingDetail: some View {
        let history = store.stats?.cycleLength.history.filter { $0.bleeding > 0 } ?? []
        let avgBleeding = history.isEmpty ? 0 : history.map(\.bleeding).reduce(0, +) / history.count

        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 20) {
                // Bar chart
                miniBarChart(values: history.map(\.bleeding), color: CyclePhase.menstrual.orbitColor)
                    .frame(height: 120)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DesignColors.structure.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                            }
                    }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 10) {
                    statPill(label: "Average", value: "\(avgBleeding) days", color: CyclePhase.menstrual.orbitColor)
                    statPill(label: "Shortest", value: "\(history.map(\.bleeding).min() ?? 0) days", color: DesignColors.textSecondary)
                    statPill(label: "Longest", value: "\(history.map(\.bleeding).max() ?? 0) days", color: DesignColors.textSecondary)
                }

                Text("Based on \(history.count) tracked cycles")
                    .font(.custom("Raleway-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
            .padding(.horizontal, 20)
        } else {
            lockedPlaceholder(message: "Your body's story unfolds after 2 complete cycles")
                .padding(.horizontal, 20)
        }
    }

    // MARK: Phase Guide Detail

    @ViewBuilder
    var phaseGuideDetail: some View {
        let currentPhase = phase ?? .follicular

        VStack(alignment: .leading, spacing: 16) {
            ForEach(CyclePhase.biologicalPhases, id: \.self) { p in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(p.orbitColor.opacity(p == currentPhase ? 0.2 : 0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: p.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(p.orbitColor.opacity(p == currentPhase ? 1 : 0.5))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(p.displayName)
                                    .font(.custom("Raleway-Bold", size: 16, relativeTo: .subheadline))
                                    .foregroundStyle(
                                        p == currentPhase ? DesignColors.text : DesignColors.textSecondary
                                    )
                                if p == currentPhase {
                                    Text("Current")
                                        .font(.custom("Raleway-Bold", size: 10, relativeTo: .caption2))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background { Capsule().fill(p.orbitColor) }
                                }
                            }
                            Text(p.description)
                                .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                                .foregroundStyle(DesignColors.textSecondary.opacity(p == currentPhase ? 1 : 0.7))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if p == currentPhase {
                        Text(p.medicalDescription)
                            .font(.custom("Raleway-Regular", size: 13.5, relativeTo: .body))
                            .foregroundStyle(DesignColors.text.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(p.orbitColor.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(p.orbitColor.opacity(0.1), lineWidth: 0.5)
                                    }
                            }
                    }
                }

                if p != CyclePhase.biologicalPhases.last {
                    Rectangle()
                        .fill(DesignColors.structure.opacity(0.06))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Detail Helpers

    @ViewBuilder
    func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Raleway-Bold", size: 18, relativeTo: .headline))
                .foregroundStyle(color)
            Text(label)
                .font(.custom("Raleway-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignColors.structure.opacity(0.05))
        }
    }

    @ViewBuilder
    func lockedPlaceholder(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignColors.textPlaceholder)
            Text(message)
                .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    func trendLabel(stdDev: Double, history: [CycleHistoryPoint]) -> String {
        guard history.count >= 3 else {
            return "Your trend is still unfolding"
        }
        let recent = history.suffix(3).map(\.length)
        let earlier = history.prefix(history.count - 3).map(\.length)
        guard !earlier.isEmpty else {
            return "Building your trend data"
        }
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let earlierAvg = Double(earlier.reduce(0, +)) / Double(earlier.count)
        let diff = recentAvg - earlierAvg
        if abs(diff) < 1.5 {
            return "Your cycle length is stable"
        } else if diff > 0 {
            return "Your cycles are trending slightly longer"
        } else {
            return "Your cycles are trending slightly shorter"
        }
    }

}
