import SwiftUI

// MARK: - Cycle Comparison Screen
//
// Push destination from `CycleDiffCard.onTap`. Renders the per-pattern
// breakdown of what shifted between this cycle and the last.
//
// Layout follows the PatternDetailScreen / CycleDetails idiom:
//
//   ┌─ AppScreenHeader ──────────────────────────────┐
//   │ SINCE LAST CYCLE                               │
//   │ 3 shifts                                       │
//   └────────────────────────────────────────────────┘
//   Date row    Mar 24 – today   ·   Feb 22 – Mar 23
//   Counter strip   [● 1 new] [● 1 cleared] [○ 2 steady]
//   ────────────────────────────────────────────────────
//   Section · New          (1)
//     ChangeItemCard — Cramps · menstrual phase + editorial
//   Section · Cleared      (1)
//     ChangeItemCard — Headaches · luteal + editorial
//   Section · Steady       (2)
//     SteadyItemRow — Bloating · 5th cycle in a row
//     SteadyItemRow — Breast tenderness · 3rd cycle in a row
//   ────────────────────────────────────────────────────
//   NOT A MEDICAL DEVICE  ⌄
//
// New / cleared items render as full cards with a tinted accent
// bloom (rose / honey) so the kind reads on a glance. Steady items
// render as compact rows — continuity is a quieter signal than a
// shift, the typography hierarchy matches.
//
// Tap on any card / row → push the existing PatternDetailScreen
// (heatmap + highlights) so the user can drill into a single
// pattern from inside the comparison view. Wiring is `onSelect` for
// now; once the destination enum is updated this becomes a route.
//
// Visual contract:
//   • `AppleHealthBackground` edge-to-edge, ScrollView in the safe
//     area. Same shell as PatternDetailScreen.
//   • Cards use `widgetCardStyle(cornerRadius: 28)` — no manual glass.
//   • No card-level scoped `.animation(value:)` — host owns motion.

struct CycleComparisonScreen: View {
    let summary: CycleDiffSummary
    let metadata: [String: ItemMeta]
    let dateRangeLabel: String  // e.g. "Mar 24 – today  ·  Feb 22 – Mar 23"
    let onSelect: (String) -> Void

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerBlock

                    if !summary.newPatterns.isEmpty {
                        section(label: "New", count: summary.newPatterns.count, kind: .new) {
                            ForEach(summary.newPatterns, id: \.self) { name in
                                ChangeItemCard(
                                    symptomDisplayName: name.capitalized,
                                    meta: metadata[name],
                                    kind: .new,
                                    onTap: { onSelect(name) }
                                )
                            }
                        }
                    }

                    if !summary.clearedPatterns.isEmpty {
                        section(label: "Cleared", count: summary.clearedPatterns.count, kind: .cleared) {
                            ForEach(summary.clearedPatterns, id: \.self) { name in
                                ChangeItemCard(
                                    symptomDisplayName: name.capitalized,
                                    meta: metadata[name],
                                    kind: .cleared,
                                    onTap: { onSelect(name) }
                                )
                            }
                        }
                    }

                    if !summary.steadyPatterns.isEmpty {
                        section(label: "Steady", count: summary.steadyPatterns.count, kind: .steady) {
                            VStack(spacing: 10) {
                                ForEach(summary.steadyPatterns, id: \.self) { name in
                                    SteadyItemRow(
                                        symptomDisplayName: name.capitalized,
                                        meta: metadata[name],
                                        onTap: { onSelect(name) }
                                    )
                                }
                            }
                        }
                    }

                    if summary.counterRows.isEmpty {
                        mirroringEmptyState
                    }

                    medicalDisclaimerFooter
                        .padding(.top, 8)
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header block (eyebrow + title + dates + counter strip)

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppScreenHeader(
                eyebrow: "SINCE LAST CYCLE",
                title: summary.displayTitle
            )

            Text(dateRangeLabel)
                .font(AppTypography.linkLabel)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.top, -18)

            if !summary.counterRows.isEmpty {
                HStack(spacing: 8) {
                    ForEach(summary.counterRows, id: \.kind) { row in
                        CounterPill(row: row)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func section<Content: View>(
        label: String,
        count: Int,
        kind: CycleDiffSummary.Kind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)

                Text("\(count)")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.65))
            }
            content()
        }
    }

    // MARK: - Mirroring empty state

    /// When no patterns shifted at all (no new / cleared / steady),
    /// the comparison is its own sentence. Rendered as a centered
    /// editorial card matching the warm RhythmReflection cadence,
    /// minus the gradient — this isn't the closing card, just a
    /// quiet reading.
    private var mirroringEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This cycle is mirroring the last.")
                .font(.raleway("SemiBold", size: 20, relativeTo: .title3))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)
            Text("Nothing showed up new, nothing cleared, nothing carried through. Bodies are like that sometimes.")
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Medical disclaimer footer

    private var medicalDisclaimerFooter: some View {
        HStack(spacing: 6) {
            Text("NOT A MEDICAL DEVICE")
                .font(AppTypography.cardEyebrow)
                .tracking(1.2)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(DesignColors.textSecondary.opacity(0.8))
        .padding(.top, 4)
    }
}

// MARK: - ItemMeta

extension CycleComparisonScreen {
    /// Per-symptom metadata the screen needs to render an item.
    /// Kept narrow on purpose — feature reducer composes this from
    /// `MenstrualLocalClient.cycleDiff()` + `patternMetrics()`.
    struct ItemMeta: Equatable, Sendable {
        let phaseDisplay: String  // e.g. "Menstrual phase"
        let editorial: String     // a single attentive sentence
        let streakLabel: String?  // for steady items only ("5th cycle in a row")
    }
}

// MARK: - Change item card (new / cleared)

/// Larger card for shifts. Eyebrow names the phase, title names the
/// symptom (Raleway SemiBold 22, matching pattern detail title), an
/// editorial sentence sits below, and a tinted accent bloom in the
/// trailing area carries the kind colour. Right-aligned chevron
/// signals push.
private struct ChangeItemCard: View {
    let symptomDisplayName: String
    let meta: CycleComparisonScreen.ItemMeta?
    let kind: CycleDiffSummary.Kind
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    if let phase = meta?.phaseDisplay {
                        Text(phase.uppercased())
                            .font(AppTypography.cardEyebrow)
                            .tracking(1.4)
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Text(symptomDisplayName)
                        .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)

                    if let editorial = meta?.editorial {
                        Text(editorial)
                            .font(.raleway("Medium", size: 15, relativeTo: .body))
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(alignment: .topTrailing) {
                accentBloom.allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: 28)
    }

    private var accentBloom: some View {
        Circle()
            .fill(kind.tint)
            .frame(width: 200, height: 200)
            .blur(radius: 75)
            .opacity(0.22)
            .offset(x: 70, y: -60)
            .accessibilityHidden(true)
    }
}

// MARK: - Steady item row (compact)

/// Compact row for carry-through patterns. No bloom, hollow leading
/// dot, streak label trailing. Reads as a list, not a card stack —
/// continuity is a quieter signal.
private struct SteadyItemRow: View {
    let symptomDisplayName: String
    let meta: CycleComparisonScreen.ItemMeta?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Circle()
                    .strokeBorder(
                        DesignColors.textSecondary.opacity(0.55),
                        lineWidth: 1.2
                    )
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(symptomDisplayName)
                        .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    if let phase = meta?.phaseDisplay {
                        Text(phase)
                            .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                if let streak = meta?.streakLabel {
                    Text(streak)
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: 22)
    }
}

// MARK: - CycleDiffSummary helpers

extension CycleDiffSummary {
    /// Title shown in the comparison screen header. "N shifts" when
    /// there are net changes (new + cleared); falls back to a
    /// descriptive phrase when the cycle is steady or fully mirrored.
    var displayTitle: String {
        let changes = newPatterns.count + clearedPatterns.count
        if changes > 0 {
            return changes == 1 ? "1 shift" : "\(changes) shifts"
        }
        if !steadyPatterns.isEmpty {
            return "Holding steady"
        }
        return "Mirroring last cycle"
    }
}

// MARK: - Mock metadata

extension CycleComparisonScreen {
    static let mockMetadataMixed: [String: ItemMeta] = [
        "cramps": ItemMeta(
            phaseDisplay: "Menstrual phase",
            editorial: "First time we've seen cramps in your menstrual phase since you started tracking.",
            streakLabel: nil
        ),
        "headaches": ItemMeta(
            phaseDisplay: "Luteal phase",
            editorial: "Was in 3 of your last 6 cycles. Not this one.",
            streakLabel: nil
        ),
        "bloating": ItemMeta(
            phaseDisplay: "Luteal phase",
            editorial: "",
            streakLabel: "5th cycle in a row"
        ),
        "breast tenderness": ItemMeta(
            phaseDisplay: "Luteal phase",
            editorial: "",
            streakLabel: "3rd cycle in a row"
        )
    ]

    static let mockDateRange = "Mar 24 – today  ·  Feb 22 – Mar 23"
}

// MARK: - Previews

#Preview("Comparison — Mixed") {
    NavigationStack {
        CycleComparisonScreen(
            summary: .mockMixed,
            metadata: CycleComparisonScreen.mockMetadataMixed,
            dateRangeLabel: CycleComparisonScreen.mockDateRange,
            onSelect: { _ in }
        )
    }
}

#Preview("Comparison — Only new") {
    NavigationStack {
        CycleComparisonScreen(
            summary: .mockOnlyNew,
            metadata: [
                "cramps": .init(
                    phaseDisplay: "Menstrual phase",
                    editorial: "First time we've seen cramps in your menstrual phase since you started tracking.",
                    streakLabel: nil
                ),
                "back pain": .init(
                    phaseDisplay: "Luteal phase",
                    editorial: "First time we've seen back pain in your luteal phase since you started tracking.",
                    streakLabel: nil
                )
            ],
            dateRangeLabel: CycleComparisonScreen.mockDateRange,
            onSelect: { _ in }
        )
    }
}

#Preview("Comparison — Only steady (holding)") {
    NavigationStack {
        CycleComparisonScreen(
            summary: .mockOnlySteady,
            metadata: [
                "bloating": .init(phaseDisplay: "Luteal phase", editorial: "", streakLabel: "5th cycle in a row"),
                "breast tenderness": .init(phaseDisplay: "Luteal phase", editorial: "", streakLabel: "3rd cycle in a row"),
                "fatigue": .init(phaseDisplay: "Luteal phase", editorial: "", streakLabel: "4th cycle in a row")
            ],
            dateRangeLabel: CycleComparisonScreen.mockDateRange,
            onSelect: { _ in }
        )
    }
}

#Preview("Comparison — Mirroring (no shifts)") {
    NavigationStack {
        CycleComparisonScreen(
            summary: .mockMirroring,
            metadata: [:],
            dateRangeLabel: CycleComparisonScreen.mockDateRange,
            onSelect: { _ in }
        )
    }
}
