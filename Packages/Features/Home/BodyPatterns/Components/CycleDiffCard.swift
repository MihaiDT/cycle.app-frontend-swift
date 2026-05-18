import SwiftUI

// MARK: - Cycle Diff Card
//
// Top-of-feed card on Body Patterns. Reads as a quick-scan delta of
// patterns since the last cycle: how many new, how many cleared,
// how many stayed steady — followed by editorial sentences that name
// them. Sits between the "How are you feeling?" LoggingActionCard and
// the "Your steady rhythms" section header.
//
// Visual treatment (cream `widgetCardStyle` glass, NOT warm gradient
// — that's reserved for the closing `CycleRhythmReflectionCard`):
//   • Tinted counter pills under the eyebrow — rose for new, honey
//     for cleared, hollow neutral ring for steady. Same dot
//     vocabulary as the cycle history timeline so the user reads it
//     without a legend.
//   • Subtle rose accent bloom in the top-trailing corner. Adds
//     warmth without competing with the WaterFillBackdrop on the
//     active pattern card below.
//   • Abstract "two cycles" linework motif (two overlapping rings)
//     in the trailing space — visual metaphor for comparison, low
//     opacity so it reads as decoration, not a control. Matches the
//     balloon-outline vocabulary on pattern cards.
//
// Voice (cycle.app): one sentence = one thought = one line. Present
// tense for new, past for cleared, "stayed steady" for steady.
// Symptom names lowercased mid-sentence; capitalized only when
// leading.
//
// Wiring (future): `BodyPatternsFeature.State.cycleDiff: CycleDiffSummary?`
// computed by `MenstrualLocalClient.cycleDiff()` running PatternDetector
// over two windows and diffing the symptomTypeRaw sets per phase.

struct CycleDiffCard: View {
    let summary: CycleDiffSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                eyebrow
                if !summary.counterRows.isEmpty {
                    counterPillsRow
                }
                sentencesBlock
                if summary.hasDrillIn {
                    footerHint
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) {
                trailingDecor
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        Text("SINCE LAST CYCLE")
            .font(AppTypography.cardEyebrow)
            .tracking(1.4)
            .foregroundStyle(DesignColors.textSecondary)
    }

    // MARK: - Counter pills (rose · honey · hollow)

    private var counterPillsRow: some View {
        HStack(spacing: 8) {
            ForEach(summary.counterRows, id: \.kind) { row in
                CounterPill(row: row)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Editorial sentences

    /// Each sentence renders as its own line — same cadence as
    /// `CycleRhythmReflectionCard.formattedCopy`. Counter pills above
    /// already carry the color story; sentences stay monochrome so
    /// the bullet-vs-text rhythm doesn't double up.
    private var sentencesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(summary.sentences.enumerated()), id: \.offset) { _, sentence in
                Text(sentence)
                    .font(.raleway("SemiBold", size: 18, relativeTo: .body))
                    .tracking(-0.15)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Footer hint

    private var footerHint: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            Text("View comparison")
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
    }

    // MARK: - Trailing decoration (bloom + motif)

    /// Two stacked layers in the top-trailing corner:
    ///   1. A soft rose bloom — adds warmth to the cream surface
    ///      without going to a full warm gradient (reserved for the
    ///      Rhythm reflection finale).
    ///   2. Two overlapping rings — abstract metaphor for "this
    ///      cycle vs the previous one". Low opacity, linework only.
    private var trailingDecor: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(DesignColors.accentWarm)
                .frame(width: 180, height: 180)
                .blur(radius: 70)
                .opacity(0.18)
                .offset(x: 70, y: -70)

            ComparisonRingsMotif()
                .stroke(DesignColors.accentWarm.opacity(0.28), lineWidth: 1.0)
                .frame(width: 88, height: 56)
                .offset(x: -14, y: 14)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Counter pill

/// Compact pill: leading dot in the kind's tint, then `count label`
/// in Raleway SemiBold. Glass capsule background with a hairline
/// border in the tint at low opacity — same chrome rhythm as the
/// cycle history rows. Reused by `CycleComparisonScreen` for the
/// header counter strip; kept internal (not `private`) on purpose.
struct CounterPill: View {
    let row: CycleDiffSummary.CounterRow

    var body: some View {
        HStack(spacing: 6) {
            dot
            Text("\(row.count) \(row.label)")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(row.kind.tint.opacity(0.18), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private var dot: some View {
        switch row.kind {
        case .new, .cleared:
            Circle()
                .fill(row.kind.tint)
                .frame(width: 6, height: 6)
        case .steady:
            Circle()
                .strokeBorder(row.kind.tint.opacity(0.65), lineWidth: 1.2)
                .frame(width: 7, height: 7)
        }
    }
}

// MARK: - Comparison rings motif

/// Two overlapping rings, drawn as a single Shape so the line weight
/// stays consistent under stroke. Low opacity — reads as decoration,
/// not as data.
private struct ComparisonRingsMotif: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) * 0.45
        let centerLeft = CGPoint(x: rect.midX - radius * 0.55, y: rect.midY)
        let centerRight = CGPoint(x: rect.midX + radius * 0.55, y: rect.midY)
        path.addEllipse(in: CGRect(
            x: centerLeft.x - radius, y: centerLeft.y - radius,
            width: radius * 2, height: radius * 2
        ))
        path.addEllipse(in: CGRect(
            x: centerRight.x - radius, y: centerRight.y - radius,
            width: radius * 2, height: radius * 2
        ))
        return path
    }
}

// MARK: - Summary model

/// Pure data the card renders. Computed elsewhere (future
/// `MenstrualLocalClient.cycleDiff()`); the card itself is dumb.
struct CycleDiffSummary: Equatable, Sendable {
    /// Symptoms appearing this cycle but not the previous one.
    var newPatterns: [String]

    /// Symptoms that were in the previous cycle but did not return
    /// this cycle.
    var clearedPatterns: [String]

    /// Symptoms present in both cycles (the carry-through set).
    var steadyPatterns: [String]

    init(
        newPatterns: [String] = [],
        clearedPatterns: [String] = [],
        steadyPatterns: [String] = []
    ) {
        self.newPatterns = newPatterns
        self.clearedPatterns = clearedPatterns
        self.steadyPatterns = steadyPatterns
    }

    /// True when the card has changes to drill into. A summary made
    /// purely of steady patterns is its own message — the
    /// "View comparison" affordance would over-promise.
    var hasDrillIn: Bool {
        !newPatterns.isEmpty || !clearedPatterns.isEmpty
    }

    // MARK: Counter rows

    enum Kind: Sendable, Equatable {
        case new, cleared, steady

        var tint: Color {
            switch self {
            case .new:     return DesignColors.accentWarm
            case .cleared: return DesignColors.accentHoney
            case .steady:  return DesignColors.textSecondary
            }
        }
    }

    struct CounterRow: Equatable, Sendable {
        let kind: Kind
        let count: Int
        let label: String
    }

    var counterRows: [CounterRow] {
        var rows: [CounterRow] = []
        if !newPatterns.isEmpty {
            rows.append(.init(kind: .new, count: newPatterns.count, label: "new"))
        }
        if !clearedPatterns.isEmpty {
            rows.append(.init(kind: .cleared, count: clearedPatterns.count, label: "cleared"))
        }
        if !steadyPatterns.isEmpty {
            rows.append(.init(kind: .steady, count: steadyPatterns.count, label: "steady"))
        }
        return rows
    }

    // MARK: Sentences

    var sentences: [String] {
        var out: [String] = []
        for symptom in newPatterns {
            out.append(newSentence(for: symptom))
        }
        for symptom in clearedPatterns {
            out.append(clearedSentence(for: symptom))
        }
        if !steadyPatterns.isEmpty {
            out.append(steadySentence(for: steadyPatterns))
        }
        if out.isEmpty {
            out.append("This cycle is mirroring the last.")
        }
        return out
    }

    private func newSentence(for symptom: String) -> String {
        "\(symptom.capitalized) is showing up this cycle."
    }

    private func clearedSentence(for symptom: String) -> String {
        "\(symptom.capitalized) cleared."
    }

    private func steadySentence(for symptoms: [String]) -> String {
        let display = listPhrase(symptoms)
        return "\(display) stayed steady."
    }

    /// Oxford-comma list with a soft cap at three carry-through items;
    /// beyond that we summarise as "and a few more" to avoid a roll
    /// call. Lowercases every item past the first so the sentence
    /// reads as one breath.
    private func listPhrase(_ items: [String]) -> String {
        guard let first = items.first else { return "" }
        let rest = items.dropFirst().map { $0.lowercased() }
        switch rest.count {
        case 0:
            return first.capitalized
        case 1:
            return "\(first.capitalized) and \(rest[0])"
        case 2:
            return "\(first.capitalized), \(rest[0]), and \(rest[1])"
        default:
            return "\(first.capitalized), \(rest.prefix(2).joined(separator: ", ")), and a few more"
        }
    }
}

// MARK: - Mock fixtures

extension CycleDiffSummary {
    static let mockMixed = CycleDiffSummary(
        newPatterns: ["cramps"],
        clearedPatterns: ["headaches"],
        steadyPatterns: ["bloating", "breast tenderness"]
    )

    static let mockOnlySteady = CycleDiffSummary(
        steadyPatterns: ["bloating", "breast tenderness", "fatigue"]
    )

    static let mockOnlyNew = CycleDiffSummary(
        newPatterns: ["cramps", "back pain"]
    )

    static let mockMirroring = CycleDiffSummary()

    static let mockMany = CycleDiffSummary(
        newPatterns: ["cramps"],
        clearedPatterns: ["headaches"],
        steadyPatterns: ["bloating", "breast tenderness", "fatigue", "low mood", "acne"]
    )
}

// MARK: - Previews

#Preview("Mixed — 1 new, 1 cleared, 2 steady") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        CycleDiffCard(summary: .mockMixed, onTap: {})
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Only steady — carry-through cycle") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        CycleDiffCard(summary: .mockOnlySteady, onTap: {})
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Only new — emerging changes") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        CycleDiffCard(summary: .mockOnlyNew, onTap: {})
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Mirroring — nothing shifted") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        CycleDiffCard(summary: .mockMirroring, onTap: {})
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Long steady list — soft cap") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        CycleDiffCard(summary: .mockMany, onTap: {})
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("In screen context — between LoggingActionCard and Active section") {
    ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY · THURSDAY")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
                Text("How are you feeling?")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: 28)

            CycleDiffCard(summary: .mockMixed, onTap: {})

            Text("Your steady rhythms")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
                .padding(.top, 4)

            RoundedRectangle(cornerRadius: 28)
                .fill(DesignColors.text.opacity(0.05))
                .frame(height: 230)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, 80)
        .padding(.bottom, 60)
    }
    .background(AppleHealthBackground().ignoresSafeArea())
}
