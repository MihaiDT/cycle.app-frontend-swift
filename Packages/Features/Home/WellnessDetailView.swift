import ComposableArchitecture
import SwiftUI

// MARK: - Wellness Detail View
//
// Presented as a sheet from Home. Renders the compact WellnessWidget up top,
// followed by the per-phase breakdown widget and the rhythm insight list.
// All copy is personal — "your average", "this cycle" — never a population norm.

public struct WellnessDetailView: View {
    @Bindable var store: StoreOf<WellnessDetailFeature>

    public init(store: StoreOf<WellnessDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    backBar
                        .padding(.top, 4)

                    WellnessWidget(
                        adjusted: store.adjusted,
                        trendVsBaseline: store.trendVsBaseline,
                        phase: store.phase,
                        cycleDay: store.cycleDay,
                        sourceLabel: store.sourceLabel,
                        compact: true
                    )

                    sectionLabel("This cycle")
                        .padding(.top, 6)

                    PhaseBreakdownWidget(
                        rows: store.rows,
                        isLoading: store.isLoadingBreakdown
                    )

                    sectionLabel("Your rhythm")
                        .padding(.top, 14)

                    insightList

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: Back bar

    @ViewBuilder
    private var backBar: some View {
        HStack(alignment: .center, spacing: 12) {
            GlassBackButton(action: { store.send(.dismissTapped) })
                .frame(width: 36, height: 36)

            Text("Wellness")
                .font(.raleway("Bold", size: 17, relativeTo: .headline))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)

            Spacer()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Section label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.raleway("Bold", size: 11, relativeTo: .caption2))
            .tracking(1.8)
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 4)
            .padding(.bottom, -4)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Insight list

    @ViewBuilder
    private var insightList: some View {
        if store.isLoadingBreakdown, store.insights.isEmpty {
            WellnessInsightCard(
                kicker: "Loading",
                message: "Pulling your rhythm together…"
            )
        } else if store.insights.isEmpty {
            WellnessInsightCard(
                kicker: "Early days",
                message: "Your rhythm becomes clear after 2 full cycles."
            )
        } else {
            VStack(spacing: 10) {
                ForEach(store.insights) { insight in
                    WellnessInsightCard(
                        kicker: insight.kicker,
                        message: insight.body
                    )
                }
            }
        }
    }
}

// MARK: - Phase Breakdown Widget

public struct PhaseBreakdownWidget: View {
    public let rows: [PhaseRow]
    public let isLoading: Bool

    public init(rows: [PhaseRow], isLoading: Bool = false) {
        self.rows = rows
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(spacing: 0) {
            if rows.isEmpty, isLoading {
                skeletonRows
            } else if rows.isEmpty {
                emptyState
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 && !row.isCurrent && !rows[index - 1].isCurrent {
                        Divider()
                            .background(DesignColors.text.opacity(0.06))
                            .padding(.leading, 16)
                    }
                    PhaseBreakdownRow(row: row)
                }
            }
        }
        .padding(8)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Phase breakdown")
    }

    @ViewBuilder
    private var skeletonRows: some View {
        ForEach(CyclePhase.biologicalPhases, id: \.self) { phase in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignColors.text.opacity(0.08))
                        .frame(width: 90, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignColors.text.opacity(0.06))
                        .frame(width: 110, height: 11)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignColors.text.opacity(0.08))
                    .frame(width: 36, height: 18)
            }
            .padding(14)
            if phase != .luteal {
                Divider()
                    .background(DesignColors.text.opacity(0.06))
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Your phase picture is forming")
                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text("Check in daily for two cycles to unlock this.")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(DesignColors.text.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: DesignColors.text.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: DesignColors.text.opacity(0.06), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Phase Row

private struct PhaseBreakdownRow: View {
    let row: PhaseRow

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.raleway("Bold", size: 14, relativeTo: .body))
                        .tracking(-0.1)
                        .foregroundStyle(DesignColors.text)

                    if row.isCurrent {
                        Text("NOW")
                            .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                            .tracking(1.2)
                            .foregroundStyle(DesignColors.accentWarm)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(DesignColors.accentWarm.opacity(0.15))
                            )
                    }
                }
                Text(subtitle)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption))
                    .tracking(0.2)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer(minLength: 8)

            scoreBlock
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var subtitle: String {
        if let avg = row.personalAverage {
            return "Your average \(avg)"
        }
        return "Not enough data yet"
    }

    @ViewBuilder
    private var scoreBlock: some View {
        HStack(alignment: .center, spacing: 6) {
            if let score = row.thisCycleScore {
                Text("\(score)")
                    .font(.raleway("Black", size: 17, relativeTo: .headline))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                if let delta = row.delta, delta != 0 {
                    deltaPill(delta)
                }
            } else {
                Text("—")
                    .font(.raleway("Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func deltaPill(_ delta: Int) -> some View {
        let isUp = delta > 0
        Text(isUp ? "+\(delta)" : "\(delta)")
            .font(.raleway("Bold", size: 11, relativeTo: .caption))
            .foregroundStyle(
                isUp ? DesignColors.accentWarmText : DesignColors.textSecondary
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isUp
                            ? DesignColors.accentWarm.opacity(0.12)
                            : DesignColors.text.opacity(0.08)
                    )
            )
    }

    @ViewBuilder
    private var rowBackground: some View {
        if row.isCurrent {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignColors.accentWarm.opacity(0.08))
        } else {
            Color.clear
        }
    }

    private var a11yLabel: String {
        var parts: [String] = [row.name]
        if row.isCurrent { parts.append("current phase") }
        if let avg = row.personalAverage { parts.append("your average \(avg)") }
        if let score = row.thisCycleScore { parts.append("this cycle \(score)") }
        if let delta = row.delta {
            parts.append(delta > 0 ? "up \(delta)" : "down \(abs(delta))")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Insight Card

public struct WellnessInsightCard: View {
    public let kicker: String
    public let message: String

    public init(kicker: String, message: String) {
        self.kicker = kicker
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker.uppercased())
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.textSecondary)
            Text(message)
                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                .tracking(-0.1)
                .foregroundStyle(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignColors.cardWarm)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignColors.text.opacity(0.05), lineWidth: 1)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kicker). \(message)")
    }
}

// MARK: - Aria Voice Line
//
// Small quoted block shown on Home beneath the WellnessWidget when the user's
// trend vs. baseline is noticeably positive. Deliberately lowercase, gentle —
// observational tone, never celebratory.

public struct AriaVoiceLine: View {
    public let phase: CyclePhase?

    public init(phase: CyclePhase?) {
        self.phase = phase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ARIA")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.accentWarm)
            Text(copy)
                .font(.raleway("Medium", size: 13, relativeTo: .body).italic())
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 2)
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 0,
                        bottomLeading: 0,
                        bottomTrailing: 12,
                        topTrailing: 12
                    ),
                    style: .continuous
                )
                .fill(DesignColors.cardWarm)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Aria. \(copy)")
    }

    private var copy: String {
        switch phase {
        case .menstrual:
            return "Rest matters most for you today. This is enough."
        case .follicular:
            return "You're riding the wave — your energy moves easily now."
        case .ovulatory:
            return "Your spark carries far today."
        case .luteal:
            return "You met yourself where you are. That's the real work."
        case .late, .none:
            return "Your body is moving at its own pace. That's okay."
        }
    }
}

// MARK: - Preview

#Preview("Detail") {
    WellnessDetailView(
        store: Store(
            initialState: WellnessDetailFeature.State(
                adjusted: 73,
                trendVsBaseline: 11,
                phase: .luteal,
                cycleDay: 22,
                sourceLabel: "Today's check-in · Health data"
            )
        ) {
            WellnessDetailFeature()
        }
    )
}

#Preview("Aria voice") {
    VStack(spacing: 16) {
        AriaVoiceLine(phase: .luteal)
        AriaVoiceLine(phase: .ovulatory)
        AriaVoiceLine(phase: .menstrual)
        AriaVoiceLine(phase: .follicular)
    }
    .padding()
    .background(DesignColors.background)
}
